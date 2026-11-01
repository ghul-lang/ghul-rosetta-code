#!/usr/bin/perl
# Keep each solution's construct notes current: up to three one-line comments
# after the `use` lines, one per ghūl construct the solution uses that a
# reader coming from another language may not know, in the order the
# constructs first appear. The notes come from the table below and nowhere
# else, so every solution says the same thing the same way. See AGENTS.md.
#
#   scripts/construct-notes.pl --check [file...]   list sources whose notes differ
#   scripts/construct-notes.pl --fix   [file...]   rewrite them in place
#   scripts/construct-notes.pl --count [file...]   print how many notes each source gets
#
# With no files, every task's main source is considered: tasks/<slug>/<slug>.ghul
# and tasks/<slug>/<part>/<part>.ghul, less the ones a format-exempt file names.
use strict; use warnings;

my @NOTES = (
    [qr/[A-Za-z_\]\)]\{\}/,                          '`T{}` is a lazy sequence of `T`, read by iterating it.'],
    [qr/[A-Za-z_\]\)\?]\[\]/,                        '`T[]` is a read-only list: an array, a `LIST` or a lazy list all fit.'],
    [qr/\|>/,                                        '`x |> f(a, b)` is `f(x, a, b)`: the left value is the first argument.'],
    [qr/[(,]\s*\*(?:\s*[,)]|\s+[-+*\/%<>=!&|~]|\s*\.\w)/, '`*` as an argument leaves that parameter open: partial application.'],
    [qr/=~|!~/,                                      '`=~` compares values (structural equality); `==` compares identity.'],
    [qr/\bif let\b|\bwhen\b/,                        '`if let` and `case ... when` pattern-match; `[x, ..rest]` matches a list.'],
    [qr/(?:\|>\s*|^\s*)list\(\)/,                    '`list()` makes a lazy `T[]`: elements are produced once, on first access.'],
    [qr/(?:\|>\s*|^\s*)(?:LIST|SET|MAP|ARRAY)\(\)/,  '`LIST()`, `SET()`, `MAP()` and `ARRAY()` build the collection eagerly.'],
    [qr/~>|\?\?/,                                    '`~>` skips the call if its left value is absent; `??` gives a fallback.'],
    [qr/\byield\b/,                                  '`yield` makes the function a generator: it returns a lazy `T{}`.'],
);
my %IS_NOTE = map { ("// $_->[1]" => 1) } @NOTES;
my $LIMIT = 3;

my $mode = shift @ARGV // '--check';
my @files = @ARGV ? @ARGV : default_files();

my $differ = 0;
for my $file (@files) {
    open my $in, '<', $file or die "$file: $!";
    my @lines = <$in>; close $in;
    chomp @lines;
    my @wanted = wanted_notes(\@lines);
    my @rewritten = with_notes(\@lines, \@wanted);
    my $same = join("\n", @lines) eq join("\n", @rewritten);
    if ($mode eq '--count') { printf "%d\t%s\n", scalar @wanted, $file; next; }
    next if $same;
    $differ++;
    if ($mode eq '--fix') {
        open my $out, '>', $file or die "$file: $!";
        print $out map { "$_\n" } @rewritten; close $out;
    } else {
        print "$file\n";
    }
}
exit($mode eq '--check' && $differ ? 1 : 0);

sub default_files {
    my %exempt;
    for my $marker (glob 'tasks/*/format-exempt tasks/*/*/format-exempt') {
        (my $dir = $marker) =~ s{/format-exempt$}{};
        open my $m, '<', $marker or next;
        while (<$m>) { chomp; next if /^\s*(#|$)/; $exempt{"$dir/$_"} = 1 }
    }
    my @all;
    for my $f (glob 'tasks/*/*.ghul tasks/*/*/*.ghul') {
        my ($dir, $base) = $f =~ m{^(.*)/([^/]+)\.ghul$};
        my ($leaf) = $dir =~ m{([^/]+)$};
        next unless $base eq $leaf;
        next if $exempt{$f};
        push @all, $f;
    }
    return sort @all;
}

# The notes a source wants, in order of first appearance, at most $LIMIT.
sub wanted_notes {
    my ($lines) = @_;
    my %first;
    my $n = 0;
    for my $raw (@$lines) {
        $n++;
        my $code = strip($raw);
        for my $i (0 .. $#NOTES) {
            next if exists $first{$i};
            $first{$i} = $n if $code =~ $NOTES[$i][0];
        }
    }
    my @order = sort { $first{$a} <=> $first{$b} || $a <=> $b } keys %first;
    return map { "// $NOTES[$_][1]" } @order[0 .. ($#order < $LIMIT - 1 ? $#order : $LIMIT - 1)];
}

# Code only: no comment, no string or character literal contents.
sub strip {
    my ($s) = @_;
    return '' if $s =~ /^\s*\/\//;
    $s =~ s{//.*$}{};
    $s =~ s{"(?:[^"\\]|\\.)*"}{""}g;
    $s =~ s{'(?:[^'\\]|\\.)*'}{''}g;
    return $s;
}

# The source with its note block replaced: the block sits after the leading
# `use` lines and the blank line that follows them, and before everything else.
sub with_notes {
    my ($lines, $wanted) = @_;
    my @src = @$lines;
    # The head is a shebang line, if any, and the leading `use` lines, a
    # multi-line `use` alias included (its brackets close before it ends).
    my $i = 0;
    my $depth = 0;
    while ($i < @src) {
        my $line = $src[$i];
        last unless $depth > 0 || $line =~ /^\s*use\b/ || $line =~ /^\s*$/ || ($i == 0 && $line =~ /^#!/);
        last if $line =~ /^\s*$/ && $depth == 0 && !($i + 1 < @src && $src[$i + 1] =~ /^\s*use\b/);
        my $code = strip($line);
        $depth += () = $code =~ /[(\[]/g;
        $depth -= () = $code =~ /[)\]]/g;
        $i++;
    }
    my @head = @src[0 .. $i - 1];
    pop @head while @head && $head[-1] =~ /^\s*$/;
    my @rest = @src[$i .. $#src];
    shift @rest while @rest && $rest[0] =~ /^\s*$/;
    if (@rest && $IS_NOTE{$rest[0]}) {
        shift @rest while @rest && $IS_NOTE{$rest[0]};
        shift @rest while @rest && $rest[0] =~ /^\s*$/;
    }
    my @out = @head;
    if (@$wanted) {
        push @out, '' if @head;
        push @out, @$wanted;
    }
    push @out, '' if @out && @rest;
    push @out, @rest;
    return @out;
}
