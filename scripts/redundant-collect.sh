#!/usr/bin/env bash
#
# Finds collect_mutable() and collect() calls a solution does not need, by
# trying without each one and keeping the change only when the task's
# captured test still passes.
#
#   scripts/redundant-collect.sh [-j N] tasks/<slug>...
#
# Each `|> collect_mutable()` or `|> collect()` site is tried last to first,
# so an edit never moves a site still to be tried. At each site the call
# is first deleted, leaving the pipe lazy; failing that, collect_mutable()
# is narrowed to collect(). An edit stays only when the test passes and
# runs no slower than three times the unedited run plus ten seconds.
#
# A site is not deleted where it ends a statement assigning a name that
# is read more than once afterwards: a pipe is a cursor, so a second
# read can see a different sequence from the first while the test
# happens not to tell. Those are reported as `flagged` for a person to
# judge; narrowing still runs there, since collect() is still a list.
#
# The test only sees output, so a removal that changes when work runs
# rather than what it produces passes unnoticed: a collect that starts
# every task or thread before any result is awaited is one. Read each
# removal before keeping it.
#
# Tasks run N at a time (default 4) under nice. Writes one line per
# site to stdout, tab-separated: file, line, call, outcome. The outcome
# is one of removed, narrowed, kept, flagged, or baseline-red for a task
# whose test failed before anything was changed.

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

process_task() {
    local task="$1"
    local baseline status elapsed limit

    read -r status baseline < <(run_test "$task")

    if [[ "$status" != 0 ]]; then
        printf '%s\t-\t-\tbaseline-red\n' "$task"
        return
    fi

    limit=$((baseline * 3 + 10))

    local file
    while IFS= read -r file; do
        local count
        count=$(perl -0777 -ne 'my $n = () = /[ \t]*\|>[ \t]*collect(?:_mutable)?\(\)/g; print "$n\n"' "$file")

        local k
        for ((k = count; k >= 1; k--)); do
            local info line call flagged
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
                my $flagged = 0;
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
                        $flagged = $reads > 1 ? 1 : 0;
                    }
                }
                print "$line\t$call\t$flagged\n";
            ' "$k" "$file")

            IFS=$'\t' read -r line call flagged <<< "$info"

            local backup
            backup=$(mktemp)
            cp "$file" "$backup"

            local outcome=kept

            if [[ "$flagged" == 0 ]]; then
                edit delete "$k" "$file"
                read -r status elapsed < <(run_test "$task")

                if [[ "$status" == 0 && "$elapsed" -le "$limit" ]]; then
                    outcome=removed
                else
                    cp "$backup" "$file"
                fi
            else
                outcome=flagged
            fi

            if [[ "$outcome" != removed && "$call" == collect_mutable ]]; then
                edit narrow "$k" "$file"
                read -r status elapsed < <(run_test "$task")

                if [[ "$status" == 0 && "$elapsed" -le "$limit" ]]; then
                    outcome="$outcome+narrowed"
                    outcome="${outcome#kept+}"
                else
                    cp "$backup" "$file"
                fi
            fi

            rm -f "$backup"

            printf '%s\t%s\t%s\t%s\n' "$file" "$line" "$call" "$outcome"
        done
    done < <(find "$task" -name '*.ghul' -not -path '*/bin/*' -not -path '*/obj/*' | sort)
}

# Rewrites site K of FILE in place: `delete` removes the call, and the
# whole line where the call stands alone on it; `narrow` turns
# collect_mutable() into collect().
edit() {
    local mode="$1" k="$2" file="$3"

    perl -0777 -i -e '
        my ($mode, $k) = (shift, shift);
        local $/;
        my $text = <>;
        my @sites;
        while ($text =~ /[ \t]*\|>[ \t]*collect(?:_mutable)?\(\)/g) {
            push @sites, [$-[0], $+[0]];
        }
        my ($start, $end) = @{$sites[$k - 1]};
        my ($line_prefix) = substr($text, 0, $start) =~ /([^\n]*)\z/;
        my ($line_suffix) = substr($text, $end) =~ /^([^\n]*)/;
        if ($mode eq "delete") {
            if ($line_prefix =~ /^\s*$/ && $line_suffix =~ /^\s*$/) {
                my $line_start = $start - length($line_prefix);
                my $line_end = $end + length($line_suffix) + 1;
                substr($text, $line_start, $line_end - $line_start) = "";
            } else {
                substr($text, $start, $end - $start) = "";
            }
        } else {
            my $matched = substr($text, $start, $end - $start);
            $matched =~ s/collect_mutable\(\)/collect()/;
            substr($text, $start, $end - $start) = $matched;
        }
        print $text;
    ' "$mode" "$k" "$file"
}

export -f process_task run_test edit

printf '%s\n' "$@" | xargs -P "$jobs" -I{} bash -c 'process_task "$1"' _ {}
