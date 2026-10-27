#!/usr/bin/env bash
#
# Finds collect_mutable() and collect() calls a solution does not need, and
# List[T], LIST[T] and T[] return types where T{} would do, by trying each
# change and keeping it only when the task's captured test still passes.
#
#   scripts/redundant-collect.sh [-j N] tasks/<slug>...
#
# Each `|> collect_mutable()` or `|> collect()` site is tried last to first,
# so an edit never moves a site still to be tried. At each site the call
# is first deleted, leaving the pipe lazy; where the call produced the
# enclosing function's result, the function's List[T], LIST[T] or T[]
# return type becomes T{} in the same edit, since a bare pipe fits
# nothing narrower. Failing that, collect_mutable() is narrowed to
# collect(). An edit stays only when the test passes and runs no slower
# than three times the unedited run plus ten seconds.
#
# Then every function still declared to return List[T], LIST[T] or T[]
# is tried with T{} instead. A caller that indexes or counts the result
# no longer compiles, so the edit stays only where every caller merely
# reads the sequence through.
#
# Where the collect ends a statement assigning a name that is read more
# than once afterwards, the call becomes memo() rather than going: every
# read of a pipe starts a fresh cursor, so a bare pipe would run again
# at each read, where memo() computes the sequence once and keeps it.
#
# The test only sees output, so a removal that changes when work runs
# rather than what it produces passes unnoticed: a collect that starts
# every task or thread before any result is awaited is one. Read each
# removal before keeping it.
#
# Tasks run N at a time (default 4) under nice. Writes one line per
# site to stdout, tab-separated: file, line, call, outcome. The outcome
# is one of removed, memoised, narrowed, kept, widened, or
# baseline-red for a task whose test failed before anything was changed.

set -uo pipefail

jobs=4

if [[ "${1:-}" == "-j" ]]; then
    jobs="$2"
    shift 2
fi

if [[ $# -eq 0 ]]; then
    echo "usage: $0 [-j N] tasks/<slug>..." >&2
    exit 2
fi

run_test() {
    local task="$1"
    local started ended

    started=$(date +%s)
    timeout 600 nice -n 10 dotnet ghul-test "$task" >/dev/null 2>&1
    local status=$?
    ended=$(date +%s)

    echo "$status $((ended - started))"
}

try_edit() {   # task limit file backup -> 0 when the edit stays
    local task="$1" limit="$2" file="$3" backup="$4"
    local status elapsed

    read -r status elapsed < <(run_test "$task")

    if [[ "$status" == 0 && "$elapsed" -le "$limit" ]]; then
        return 0
    fi

    cp "$backup" "$file"
    return 1
}

process_task() {
    local task="$1"
    local baseline status elapsed limit

    read -r status baseline < <(run_test "$task")

    if [[ "$status" != 0 ]]; then
        printf '%s\t-\t-\tbaseline-red\n' "$task"
        return
    fi

    limit=$((baseline * 3 + 10))

    local files
    files=$(find "$task" -name '*.ghul' -not -path '*/bin/*' -not -path '*/obj/*' | sort)

    local file
    while IFS= read -r file; do
        local count
        count=$(perl -0777 -ne 'my $n = () = /[ \t]*\|>[ \t]*collect(?:_mutable)?\(\)/g; print "$n\n"' "$file")

        local k
        for ((k = count; k >= 1; k--)); do
            local info line call reread
            info=$(perl -0777 -e '
                my $k = shift;
                local $/;
                my $text = <>;
                my @sites;
                while ($text =~ /[ \t]*\|>[ \t]*(collect(?:_mutable)?)\(\)/g) {
                    push @sites, [$-[0], $+[0], $1];
                }
                my ($start, $end, $call) = @{$sites[$k - 1]};
                my $line = 1 + (substr($text, 0, $start) =~ tr/\n//);
                my @lines = split /\n/, $text, -1;
                my $rest = substr($text, $end);
                my ($after) = $rest =~ /^([^\n]*)/;
                my ($next) = $rest =~ /^[^\n]*\n([^\n]*)/;
                my $terminal = $after =~ /^\s*;?\s*$/ &&
                    !(defined $next && $next =~ /^\s*(\|>|~>|\.)/);
                my $reread = 0;
                if ($terminal) {
                    my $head = $line - 1;
                    $head-- while $head > 0 && $lines[$head] =~ /^\s*(\|>|~>|\.)/;
                    my $name;
                    if ($lines[$head] =~ /^\s*let\s+(\w+)/) {
                        $name = $1;
                    } elsif ($lines[$head] =~ /^\s*(\w+)\s*=[^=~]/) {
                        $name = $1;
                    }
                    if (defined $name) {
                        my $after_head = join "\n", @lines[$head + 1 .. $#lines];
                        my $reads = () = $after_head =~ /\b\Q$name\E\b/g;
                        $reread = $reads > 1 ? 1 : 0;
                    }
                }
                print "$line\t$call\t$reread\n";
            ' "$k" "$file")

            IFS=$'\t' read -r line call reread <<< "$info"

            local backup
            backup=$(mktemp)
            cp "$file" "$backup"

            local outcome=kept

            if [[ "$reread" == 1 ]]; then
                edit memo "$k" "$file"
                try_edit "$task" "$limit" "$file" "$backup" && outcome=memoised
            else
                edit delete "$k" "$file"
                try_edit "$task" "$limit" "$file" "$backup" && outcome=removed
            fi

            if [[ "$outcome" == kept && "$call" == collect_mutable ]]; then
                edit narrow "$k" "$file"
                try_edit "$task" "$limit" "$file" "$backup" && outcome=narrowed
            fi

            rm -f "$backup"

            printf '%s\t%s\t%s\t%s\n' "$file" "$line" "$call" "$outcome"
        done
    done <<< "$files"

    while IFS= read -r file; do
        local count
        count=$(perl -ne 'print "x" if /^\s*[a-z_]+(\[[^\]]*\])?\(.*\)\s*->\s*(?:(?:Collections\.)?(?:List|LIST)\[.*\]|.*\[\])\s*(?:is|=>)\s*$/' "$file" | wc -c)

        local k
        for ((k = count; k >= 1; k--)); do
            local line
            line=$(perl -ne 'print "$.\n" if /^\s*[a-z_]+(\[[^\]]*\])?\(.*\)\s*->\s*(?:(?:Collections\.)?(?:List|LIST)\[.*\]|.*\[\])\s*(?:is|=>)\s*$/' "$file" | sed -n "${k}p")

            local backup
            backup=$(mktemp)
            cp "$file" "$backup"

            local outcome=kept

            edit widen "$line" "$file"

            try_edit "$task" "$limit" "$file" "$backup" && outcome=widened

            rm -f "$backup"

            printf '%s\t%s\t%s\t%s\n' "$file" "$line" return "$outcome"
        done
    done <<< "$files"
}

# Rewrites FILE in place. `delete K` removes collect site K, and the whole
# line where the call stands alone on it, and where the site is the
# enclosing function's result, widens that function's return type;
# `narrow K` turns site K's collect_mutable() into collect(), `memo K`
# turns either call into memo(); `widen L`
# changes the return type of the function declared on line L to T{}.
edit() {
    local mode="$1" k="$2" file="$3"

    perl -0777 -i -e '
        my ($mode, $k) = (shift, shift);
        local $/;
        my $text = <>;

        sub widened {
            my ($ret) = @_;
            return "$1\{}" if $ret =~ /^(?:Collections\.)?(?:List|LIST)\[(.*)\]$/;
            return "$1\{}" if $ret =~ /^(.*)\[\]$/;
            return undef;
        }

        if ($mode eq "widen") {
            my @lines = split /\n/, $text, -1;
            my $l = $lines[$k - 1];
            if ($l =~ /^(\s*[a-z_]+(?:\[[^\]]*\])?\(.*\)\s*->\s*)(.+?)(\s*(?:is|=>)\s*)$/) {
                my $w = widened($2);
                $lines[$k - 1] = "$1$w$3" if defined $w;
            }
            print join "\n", @lines;
            exit;
        }

        my @sites;
        while ($text =~ /[ \t]*\|>[ \t]*collect(?:_mutable)?\(\)/g) {
            push @sites, [$-[0], $+[0]];
        }
        my ($start, $end) = @{$sites[$k - 1]};
        my ($line_prefix) = substr($text, 0, $start) =~ /([^\n]*)\z/;
        my ($line_suffix) = substr($text, $end) =~ /^([^\n]*)/;

        if ($mode eq "narrow" || $mode eq "memo") {
            my $matched = substr($text, $start, $end - $start);
            $matched =~ s/collect_mutable\(\)/collect()/ if $mode eq "narrow";
            $matched =~ s/collect(?:_mutable)?\(\)/memo()/ if $mode eq "memo";
            substr($text, $start, $end - $start) = $matched;
            print $text;
            exit;
        }

        my $line = 1 + (substr($text, 0, $start) =~ tr/\n//);
        my @lines = split /\n/, $text, -1;
        my ($next) = substr($text, $end) =~ /^[^\n]*\n([^\n]*)/;
        my $terminal = $line_suffix =~ /^\s*;?\s*$/ &&
            !(defined $next && $next =~ /^\s*(\|>|~>|\.)/);

        my $header;
        if ($terminal) {
            my ($indent) = $lines[$line - 1] =~ /^(\s*)/;
            for (my $i = $line - 2; $i >= 0; $i--) {
                last if $lines[$i] =~ /^\s*(si|esac|od|fi)\s*$/ && length(($lines[$i] =~ /^(\s*)/)[0]) < length($indent);
                if ($lines[$i] =~ /^(\s*)[a-z_]+(?:\[[^\]]*\])?\(.*\)\s*->\s*(.+?)\s*(is|=>)\s*$/
                    && length($1) < length($indent)) {
                    my ($hindent, $form) = ($1, $3);
                    my $head = $line - 1;
                    $head-- while $head > 0 && $lines[$head] =~ /^\s*(\|>|~>|\.)/;
                    my $result = $form eq "=>";
                    if (!$result) {
                        $result = 1 if $lines[$head] =~ /^\s*return\b/;
                        my $j = $line;
                        $j++ while $j < @lines && $lines[$j] =~ /^\s*$/;
                        $result = 1 if $j < @lines && $lines[$j] =~ /^\Q$hindent\Esi\s*$/
                            && $lines[$head] !~ /^\s*(let\b|\w+\s*=[^=~])/;
                    }
                    $header = $i if $result;
                    last;
                }
            }
        }

        if ($line_prefix =~ /^\s*$/ && $line_suffix =~ /^\s*$/) {
            my $line_start = $start - length($line_prefix);
            my $line_end = $end + length($line_suffix) + 1;
            substr($text, $line_start, $line_end - $line_start) = "";
        } else {
            substr($text, $start, $end - $start) = "";
        }

        if (defined $header) {
            @lines = split /\n/, $text, -1;
            if ($lines[$header] =~ /^(\s*[a-z_]+(?:\[[^\]]*\])?\(.*\)\s*->\s*)(.+?)(\s*(?:is|=>)\s*)$/) {
                my $w = widened($2);
                $lines[$header] = "$1$w$3" if defined $w;
            }
            $text = join "\n", @lines;
        }

        print $text;
    ' "$mode" "$k" "$file"
}

export -f process_task run_test try_edit edit

printf '%s\n' "$@" | xargs -P "$jobs" -I{} bash -c 'process_task "$1"' _ {}
