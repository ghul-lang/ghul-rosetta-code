#!/usr/bin/perl
# Keep each solution's construct notes current: a comment block after the
# `use` lines with one note for each ghūl construct the solution uses that a
# reader from another language may not know. Every construct present gets its
# note, in the fixed order of the table below, which puts a note after the
# ones whose terms it uses. The wording comes from the table and nowhere else,
# so every solution says the same thing the same way. See AGENTS.md.
#
#   scripts/construct-notes.pl --check [file...]   list sources whose notes differ
#   scripts/construct-notes.pl --fix   [file...]   rewrite them in place
#   scripts/construct-notes.pl --count [file...]   print how many note lines each source gets
#
# With no files, every task's main source is considered: tasks/<slug>/<slug>.ghul
# and tasks/<slug>/<part>/<part>.ghul, less the ones a format-exempt file names.
use strict; use warnings;

my $WIDTH = 76;

# Each construct: a name, the patterns that detect it (on every line that is
# not a whole-line comment), the note, and for a library type its name, so
# that a solution declaring a type of that name itself gets no note for it - text, or a sub that builds the
# text from which of the patterns matched.
my @CONSTRUCTS = (
    { name => 'sequence', patterns => [qr/[A-Za-z_\]\)]\{\}/],
      note => '`T{}` is the lazy sequence trait - elements are read on demand and in order from its source' },
    { name => 'list', patterns => [qr/[A-Za-z_\]\)\?]\[\]/],
      note => '`T[]` is the read-only list trait - elements can be read by index' },
    { name => 'LIST', type => 'LIST', patterns => [qr/\bLIST\b/],
      note => '`LIST[T]` is a mutable list that grows as elements are added' },
    { name => 'SET', type => 'SET', patterns => [qr/\bSET\b/],
      note => '`SET[T]` is a mutable set, holding each element once' },
    { name => 'MAP', type => 'MAP', patterns => [qr/\bMAP\b/],
      note => '`MAP[K, V]` is a mutable map from keys to values' },
    { name => 'STACK', type => 'STACK', patterns => [qr/\bSTACK\b/],
      note => '`STACK[T]` is a mutable last-in, first-out stack' },
    { name => 'QUEUE', type => 'QUEUE', patterns => [qr/\bQUEUE\b/],
      note => '`QUEUE[T]` is a mutable first-in, first-out queue' },
    { name => 'LINKED_LIST', type => 'LINKED_LIST', patterns => [qr/\bLINKED_LIST\b/],
      note => '`LINKED_LIST[T]` is a mutable doubly linked list' },
    { name => 'ARRAY', type => 'ARRAY', patterns => [qr/\bARRAY\b/],
      note => '`ARRAY[T]` is a fixed-size, read-only array' },
    { name => 'list()', patterns => [qr/(?:\|>\s*|^\s*)list\(\)/],
      note => '`list()` returns a `T[]` over a `T{}` sequence. It is lazy - a read by index materialises the source only as far as that index and caches what it read' },
    { name => 'pipe-constructors', patterns => [map { my $n = $_; qr/\|>\s*$n\b\s*(?:\[[^\]]*\])?\s*\(/ } qw(LIST SET MAP ARRAY)],
      note => sub {
          my ($hit) = @_;
          my @names = map { '`|> ' . (qw(LIST SET MAP ARRAY))[$_] . '()`' } grep { $hit->[$_] } 0 .. 3;
          return undef unless @names;
          return "$names[0] reads the whole sequence into a new `" . (qw(LIST SET MAP ARRAY))[(grep { $hit->[$_] } 0 .. 3)[0]] . '`'
              if @names == 1;
          my $list = join(', ', @names[0 .. $#names - 1]) . ' and ' . $names[-1];
          return "$list read the whole sequence into new collections";
      } },
    { name => 'yield', patterns => [qr/\byield\b/],
      note => '`yield` in a function makes it a generator, returning a lazy `T{}` sequence' },
    { name => 'thread-first', patterns => [qr/\|>/, qr/~>/],
      note => '`|>` is the thread-first operator - `x |> f(a, b)` means `f(x, a, b)`' },
    { name => 'absent-coalescing', patterns => [qr/~>/],
      note => '`~>` is the absent-coalescing thread-first operator - it skips the call when the left value is absent, and the result is then absent too' },
    { name => 'partial', patterns => [qr/[(,]\s*\*(?:\s*[,)]|\s+[-+*\/%<>=!&|~]|\s*\.\w)/],
      note => '`*` as an argument is partial application - `f(*, b)` means `a => f(a, b)`' },
    { name => 'equality', patterns => [qr/=~|!~/, qr/==|!=/],
      note => sub {
          my ($hit) = @_;
          my @parts;
          push @parts, '`=~` compares values (structural equality)' if $hit->[0];
          push @parts, '`==` compares identity' if $hit->[1];
          return @parts ? join(' - ', @parts) : undef;
      } },
    { name => 'patterns', patterns => [qr/\bif let\b/, qr/\bwhen\b/, qr/\[\s*(?:\]|\w+\s*,\s*\.\.|\.\.)/],
      note => sub {
          my ($hit) = @_;
          my @subjects = grep { $hit->[$_] } (0, 1);
          return undef unless @subjects;
          my $subject = join ' and ', map { ('`if let`', '`case ... when`')[$_] } @subjects;
          my $text = $subject . (@subjects == 1 ? ' pattern-matches' : ' pattern-match');
          $text .= ', and `[x, ..rest]` matches a list head and tail' if $hit->[2];
          return $text;
      } },
    { name => 'memo', patterns => [qr/\bmemo\s+(?:=>|is\b|rec\b|pure\b)|\b(?:rec|pure)\s+memo\b|\bmemo\s*$/],
      note => '`memo` on a function caches its results - a call with arguments equal to an earlier call\'s returns the cached result, recursive calls included' },
);

# The block is the run of comment lines straight after the head whose first
# line opens with a backtick - `// \``. No comment a solution writes itself
# opens that way there, so the block is found whatever its wording, and is
# replaced in full each time: a reworded note, or a construct added to or
# removed from the source, leaves exactly one current block. The block ends at
# the first line that is not a comment, and is always followed by a blank line.

my $mode = shift @ARGV // '--check';
my @files = @ARGV ? @ARGV : default_files();

my $differ = 0;
for my $file (@files) {
    open my $in, '<', $file or die "$file: $!";
    my @lines = <$in>; close $in;
    chomp @lines;
    my @wanted = wanted_notes(\@lines);
    my @rewritten = with_notes(\@lines, \@wanted);
    if ($mode eq '--count') { printf "%d\t%s\n", scalar @wanted, $file; next; }
    next if join("\n", @lines) eq join("\n", @rewritten);
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

# The note lines a source wants: one note for each construct it uses, each
# wrapped to $WIDTH, in the order of the table.
sub wanted_notes {
    my ($lines) = @_;
    my @first;   # per construct: per pattern, the first line it matched
    my $n = 0;
    for my $raw (@$lines) {
        $n++;
        my $code = strip($raw);
        for my $c (0 .. $#CONSTRUCTS) {
            my $patterns = $CONSTRUCTS[$c]{patterns};
            for my $p (0 .. $#$patterns) {
                next if defined $first[$c][$p];
                $first[$c][$p] = $n if $code =~ $patterns->[$p];
            }
        }
    }
    # A type the solution declares itself is its own, not the library one a
    # type note describes.
    my %declared = map { /^\s*(?:class|struct|union|trait|enum)\s+([A-Za-z_][A-Za-z0-9_]*)/ ? ($1 => 1) : () } @$lines;

    my @notes;
    for my $c (0 .. $#CONSTRUCTS) {
        next if defined $CONSTRUCTS[$c]{type} && $declared{$CONSTRUCTS[$c]{type}};
        my $patterns = $CONSTRUCTS[$c]{patterns};
        my @hit = map { defined $first[$c][$_] ? 1 : 0 } 0 .. $#$patterns;
        next unless grep { $_ } @hit;
        my $note = $CONSTRUCTS[$c]{note};
        my $text = ref $note ? $note->(\@hit, $first[$c]) : $note;
        push @notes, $text if defined $text;
    }
    return map { wrap($_) } @notes;
}

# One note as comment lines no wider than $WIDTH, its continuation lines
# indented by two spaces. A backtick span is never broken across lines.
sub wrap {
    my ($text) = @_;
    my @out;
    my $line = '//';
    my $lead = '//';
    my @words = $text =~ /`[^`]*`[^\s`]*|[^\s`]+/g;
    for my $word (@words) {
        if (length("$line $word") > $WIDTH && $line ne $lead) {
            push @out, $line;
            $lead = '//  ';
            $line = '// ';
        }
        $line .= " $word";
    }
    push @out, $line;
    return @out;
}

# A whole-line comment is not code: it is skipped, so the notes never detect
# themselves. Everything else on the line counts.
sub strip {
    my ($line) = @_;
    return $line =~ m{^\s*//} ? '' : $line;
}

# The source with its note block replaced. The block sits after the head -
# a shebang line, if any, and the leading `use` lines, a multi-line `use`
# alias included - and before everything else; an existing block is the run
# of comment lines there that opens with a note.
sub with_notes {
    my ($lines, $wanted) = @_;
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
    if (@$wanted) {
        push @out, '' if @head;
        push @out, @$wanted;
    }
    push @out, '' if @out && @rest;
    push @out, @rest;
    return @out;
}
