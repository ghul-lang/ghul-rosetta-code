#!/usr/bin/perl
# Keep the generated construct notes out of the solutions. The notation a
# section lists is derived from the code when it is published (tools/rosetta,
# notation.ghul), so a source carries no comment block for it. A block is the
# run of comment lines straight after the head whose first line opens with a
# backtick - `// \``; hand-written comments never open that way there.
#
#   scripts/construct-notes.pl --check [file...]   list sources that carry a block
#   scripts/construct-notes.pl --fix   [file...]   remove the block in place
#
# With no files, every task's main source is considered: tasks/<slug>/<slug>.ghul
# and tasks/<slug>/<part>/<part>.ghul, less the ones a format-exempt file names.
use strict; use warnings;

my $mode = shift @ARGV // q(--check);
my @files = @ARGV ? @ARGV : default_files();

my $differ = 0;
for my $file (@files) {
    open my $in, q(<), $file or die "$file: $!";
    my @lines = <$in>; close $in;
    chomp @lines;
    my @rewritten = without_notes(\@lines);
    next if join("\n", @lines) eq join("\n", @rewritten);
    $differ++;
    if ($mode eq q(--fix)) {
        open my $out, q(>), $file or die "$file: $!";
        print $out map { "$_\n" } @rewritten; close $out;
    } else {
        print "$file\n";
    }
}
exit($mode eq q(--check) && $differ ? 1 : 0);

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

# A whole-line comment is not code, so it does not count towards the head.
sub strip {
    my ($line) = @_;
    return $line =~ m{^\s*//} ? '' : $line;
}

# The source without its note block. The block sits after the head - a
# shebang line, if any, and the leading `use` lines, a multi-line `use`
# alias included - and before everything else.
sub without_notes {
    my ($lines) = @_;
    my @src = @$lines;
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
    if (@rest && $rest[0] =~ m{^// `}) {
        shift @rest while @rest && $rest[0] =~ m{^//};
        shift @rest while @rest && $rest[0] =~ /^\s*$/;
    }
    my @out = @head;
    push @out, '' if @out && @rest;
    push @out, @rest;
    return @out;
}
