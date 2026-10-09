# ghūl solutions for Rosetta Code

Working repository for [ghūl](https://ghul.dev) solutions to [Rosetta Code](https://rosettacode.org)
tasks. Every solution is written, built and run here, and its output captured as a test, before it
is posted to the wiki. Nothing goes up untested, and a compiler or runtime change that breaks a
posted solution shows up as a failing test here rather than as a wrong answer on the wiki.

## layout

- `tasks/<slug>/` - one runnable .NET project per Rosetta task. The slug is the task title
  lowercased with runs of non-alphanumeric characters collapsed to a hyphen, so `Hello world/Text`
  is `hello-world-text`.
- `tasks/<slug>/task.json` - the task's title, its wiki URL, a copy of its state from the
  ledger, and its tags and interest score (see 'tags and the index' below).
- `tasks/<slug>/notes.md` - optional, and rare: explanatory prose ahead of the code. See
  'writing explanatory text' below.
- `tasks/<slug>/run.expected` - the test expectation: the output the program must produce. The
  project is the test case - `ghulflags` and the `*.expected` files sit beside the source, and
  `dotnet ghul-test --use-dotnet-build tasks/<slug>` runs it in place.
- `rosetta-code.ghulproj` and `root/entry.ghul` - a stub that names every task's source so the
  editor loads them all in one analysis session. It builds as a library, which type-checks every
  solution in one pass, but it produces none of the programs: each task is a program in its own
  right and carries its own top-level statements. Build and run tasks individually.
- `ledger/` - the ledger: one file per task that has been done, queued, rejected or blocked, and why.
- `scripts/new-task.sh` - scaffolds a task and its test.
- `scripts/ledger-only.sh` - whether a change touches nothing but the ledger, which the ledger,
  review and CI workflows all ask it rather than each keeping a copy of the test.
- `scripts/redundant-collect.sh` - finds `collect_mutable()` and `collect()` calls a solution does not need,
  by trying each task without them and keeping only what its test still passes. A collect that
  starts work, such as launching tasks or threads, changes timing the test cannot see, so read
  each removal before keeping it.
- `tools/rosetta/` - the ledger and the wiki client.
- `GHUL.md` - language reference, a copy of the master in the
  [`ghul`](https://github.com/degory/ghul) repo. Refresh it when it falls behind; never edit it
  here.

## adding a task

```sh
scripts/new-task.sh binary-digits "Binary digits"
```

Write the solution in `tasks/binary-digits/binary-digits.ghul`, then run it and capture what it
prints:

```sh
dotnet run --project tasks/binary-digits
dotnet ghul-test --use-dotnet-build tasks/binary-digits
scripts/capture.sh tasks/binary-digits
```

`capture.sh` promotes the produced output to `run.expected`. Read the output first and satisfy
yourself it is what the task asks for - capturing is how a wrong answer becomes a permanent
expectation.

It refuses a task that did not compile. Captured, those errors would become what the test
asserts, and it would pass from then on by continuing to fail to build. A task that cannot be
written yet is recorded as blocked against the issue that stops it, rather than committed as a
broken build with its errors pinned.

## showing a task more than one way

Some tasks are worth showing twice - the built-in one-liner, and the same thing written out. Those
are held as **parts**: numbered sub-projects of the task, each a whole program with its own test.

```sh
scripts/new-part.sh apply-a-callback-to-an-array 01-using-map
```

```
tasks/apply-a-callback-to-an-array/
    task.json
    01-using-map/           a whole program, with its own .ghulproj
    02-writing-apply/
```

Each part becomes one `===heading===` section of the entry, with its own source and its own output,
in the order the numbers give. The heading comes from the directory name, so `01-using-map` is
"Using map". A task with parts has no source of its own: move the existing one into a part and
delete the task's `.ghulproj` and `ghul.json`, or the two projects collide over the entry point.

Parts are for a task that genuinely reads better as two entries. A solution that simply prints
several things is one part.

## Getting the markup to paste

```sh
scripts/generate-wiki.sh --all           # writes wiki-out/<slug>.wiki for every working task
scripts/generate-wiki.sh --solved        # the same, for the tasks not yet on the wiki
scripts/generate-wiki.sh --out amb quine # the same, for the tasks named
scripts/generate-wiki.sh y-combinator    # one task, to stdout
```

Generating reads each task's files and builds nothing: the output shown is what the task's test
captured in `run.expected`, so run the test first when a solution's output has changed.
A publish run posts either the slugs it is given or every solved task, so `--solved` and `--out`
generate exactly what it will read and leave the rest of `wiki-out/` alone.

Each file is the complete section: the `{{header|ghul}}` heading, the source in a
`<syntaxhighlight>` block, and the program's output in a `{{out}}` block. The source is read from
the task and the output is its test's `run.expected`, which the test holds equal to what the
program prints, so a solution whose output changed needs its test recaptured before its markup is
generated. The same rendering, by `rosetta section`, is what the index compares with the ledger to
mark a task whose solution is newer than the section on the wiki.

A control character in that output is shown as its Unicode picture - the escape character as
␛, the bell as ␇ - with a line under the block saying what they stand for. A wiki page cannot
carry a control character: what comes back is a replacement character, so a section holding one
never matches what was sent and can never be recognised as this repository's again. The test is
unaffected and still asserts the real bytes in `run.expected`. Tab and newline are left alone.

A task that reads standard input is the exception. The test runner paces what it sends against
what the program has printed, so running the task here with nothing on standard input produces a
transcript of prompts with no answers in it. For those the captured `run.expected` is the output,
since it is the transcript the runner produced and nothing else reproduces it - which means an
edited solution of that kind needs its test recapturing before its markup is generated.

The bulk forms print the task's wiki URL beside each file. The single-task form prints the URL to stderr,
so stdout stays exactly what goes on the page and can be piped:

```sh
scripts/generate-wiki.sh y-combinator | xclip -selection clipboard
```

A task whose test carries a `disabled` marker is skipped rather than emitted, as is one that
fails to build or run - an entry that does not run should not be posted.

`rosetta diff` shows what a publish would change, without signing in: one line a task, `new`
where the page has no ghul section yet, `same` or `differs` against the live section, and
`edited` where the live section is not the one published from here, and `unrecorded` where
nothing records what was published, which `publish` refuses until `rosetta adopt` records it. It reads every published
and solved task, or only the slugs given, and leaves each differing live section beside its
markup as `wiki-out/<slug>.live`.

`rosetta publish` puts these on the wiki. `--minor` marks its edits as minor in the page history, for a run
that only reformats sections already there. A run waits 30 seconds between tasks;
`ROSETTA_PACE_SECONDS` lengthens that when the wiki is slow. To paste one by hand instead, it goes in alphabetical
position among the language headers: `ghul` sorts after `Genie` and before `Go`. Either way, run
`rosetta sync` afterwards so the ledger records it.

Run everything with:

```sh
dotnet ghul-test --use-dotnet-build tasks
```

The tests assert the program's output only. There are deliberately no IL snapshots: a test folder
with no `il.expected` has its IL ignored.

## pictures

A solution that draws writes a PNG with `ghul.raster` and names it on standard output, which
`Raster.IMAGE.show` does as `<<image plot.png>>`. Its test asserts the file byte for byte against
the `plot.png.expected` beside it, the markup turns that line into a `[[File:Ghul-<slug>-plot.png]]`
reference, and `rosetta publish` uploads the file under that name before editing the page. The
title carries the slug because the wiki's File: namespace is shared with every other language
there.

An animation is one file too - `Raster.ANIMATION` writes its frames as an animated PNG, shown by
the same line and asserted by the same kind of expectation - but it goes on the wiki as a GIF.
MediaWiki keeps every frame of a GIF in the scaled thumbnail an entry shows, while a scaled
animated PNG is its first frame alone. So the markup names `plot.gif` wherever the PNG holds more
than one frame, and publishing rewrites the frames as a GIF and uploads that. Only the PNG is kept
here: it is what the test asserts, and what the index and ghul.dev refer to.
`tasks/animate-a-pendulum` is one.

## writing solutions for the wiki

The wiki page is the audience, so the solution has to read well standing on its own, next to
implementations in fifty other languages.

- Do what the task says, including the parts that look arbitrary. Solving a tidier nearby problem
  is the main thing that irritates reviewers there.
- Keep the program self-contained and free of scaffolding a reader has to skip past.
- Prefer the idiomatic ghūl over the shortest ghūl, and over a transliteration of the page's C#
  entry: thread the global pipe functions with `|>` rather than nesting them, prefer functions to
  classes and expression bodies to blocks, and use the constructs the language next door has no
  word for. `AGENTS.md` has the detail.
- Keep the test deterministic, which the task itself need not be. Seed a generator, or assert the
  property the task is about and print that. Ship a task's input file rather than fetching it.
  No clocks and no local paths.
- A program that reads from standard input is driven by a `run.in` beside the test, and its
  transcript is the expectation. That is how an interactive task is tested here.
- Keep lines under 64 columns, and never past 76. A solution is read in a fixed-width block on
  Rosetta Code and in a prose column about 77 characters wide on ghul.dev, so anything longer
  scrolls out of sight. `scripts/check-width.sh` reports the offenders.
- Rosetta Code's syntax highlighter has no ghūl lexer, so the code goes in a
  `<syntaxhighlight lang="ghul">` block, which it renders unhighlighted rather than rejecting.
  Follow it with the real captured output in a `{{out}}` block.

## writing explanatory text

Most tasks need nothing beyond the code and its output - the two together are the entry, and
that is the default here. Some read better with a sentence or two ahead of the code, for what the
language is doing, a design choice a reader would otherwise infer, or an explanation the task
itself asks for. `AGENTS.md` has the rule, including what does not earn one. Where a task carries
such a note, it goes in `notes.md` beside its source (or beside a part's, for a task with parts):

```
tasks/binary-digits/
    notes.md
    binary-digits.ghul
    ...
```

It is Markdown, and `scripts/generate-wiki.sh` converts it to wiki markup and places it ahead of
the `<syntaxhighlight>` block. The supported subset is deliberately small: paragraphs, `#`/`##`
headings, `*`/`-` bullet lists, `1.` numbered lists, `**bold**`, `*italic*`, `` `code` `` and
`[link text](url)`. Anything else in the file is passed through unconverted rather than dropped,
so a construct outside the subset is visible on the rendered page rather than silently missing.

```sh
dotnet run --project tools/rosetta -- render-notes tasks/binary-digits/notes.md
```

renders one file on its own, for reading before it goes anywhere.

**A task carrying `notes.md` is not one to wave through unread.** The code is covered by the
test; the prose is not, and it is read on the page the way the code is not - as an argument
rather than as an assertion. `scripts/generate-wiki.sh`'s bulk forms mark such a task `(notes)`
in their report line, and `scripts/publish.sh` names it again before publishing. Neither of those
is a gate by itself: read the rendered text before the branch that adds one is merged, and again
before it is published.

## running a solution in the playground

Each entry opens with a link to the task's page on ghul.dev, at `/rosetta/<slug>`, which
frames the [ghūl playground](https://ghul.dev/playground/) with the solution and runs it. The
playground fetches the source from this repository's `main` branch, so a link
needs nothing but the task being here under that name. The parameter names a part for a task
with parts (`<slug>/<NN-part>`), and the template keeps only the slug: the page shows every part.

The link is written as `{{ghul playground|<slug>}}`, transcluding the wiki's
[Template:Ghul playground](https://rosettacode.org/wiki/Template:Ghul_playground).
The entry says only which program to open, so the wording around the link is
changed for every entry at once by editing that template, with nothing
republished.

Not every solution can run there. The playground compiles one source file
against a short list of reference assemblies - the ghūl runtime, `ghul.raster`
and the parts of .NET that work in a browser - and runs the program in the
page. It supplies standard input a line at a time from a box under the output,
shows the images a program draws, and runs threads. Its filesystem is in
memory, holding the files the program names (below) and whatever it writes
itself. What it cannot do is reach the network, start another process, or end
with `Environment.exit`, and it runs heavy computation tens of times slower
than the same program runs natively. A program that needs one of those, or
takes minutes there, carries a `playground-unsupported` file beside its
source, holding one line saying why:

```
tasks/execute-a-system-command/
    playground-unsupported      it starts another process, which a program running in a browser cannot do
    execute-a-system-command.ghul
    ...
```

`scripts/generate-wiki.sh` writes no link for such a program, and the playground
shows the reason to anyone who opens it by URL anyway. Referencing a package
other than `ghul.raster` is the one case the script can see for itself; one
without the file is reported, and gets no link. Everything else can only be
told by reading the program, so the file is written when the solution is. That
includes a program that reads standard input: the playground can supply it,
so what decides is what the program does with it, such as echoing each line
back beside the playground's own echo.

A program that reads files names them in a `playground-files` file beside its
source, one path per line relative to that directory. The playground fetches
each one and puts it where the program opens it by its bare name, so a file
shared through `data/` is listed by its path there (`../../data/unixdict.txt`).

## status

`ledger/` is the ledger: one file per task that has been done or decided about, keyed by its
Rosetta Code title and named for its slug, or for a key made from the title while it has none. One
file per task is what lets two branches working on different tasks land in either order without
touching the same file.

| state | meaning |
|-------|---------|
| `queued` | picked to work on, not written yet |
| `solved` | written and tested here, not on the wiki |
| `published` | on the wiki |
| `rejected` | will not be attempted; `reason` says why, and it is not revisited |
| `blocked` | cannot be written yet; `reason` names the issue, and it is revisited when that closes |

A rejection is a decision, not a note to self, so it carries one of a fixed set of reasons:
`needs-gui`, `needs-network`, `needs-interaction`, `nondeterministic`, `needs-native-lib`,
`output-unbounded`, `no-equivalent`, `excluded`, `task-unclear`. The point of writing it down is
that the same task is never assessed twice.

`rosetta reopen <title> <why>` reverses one, for when what made the task impossible stops being
true. It records the verdict it overturned in the entry's note, so the reversal is readable rather
than looking like a task nobody ever decided about.

Only tasks that have been judged are in the ledger. The 1300-odd others are whatever
`Category:Programming Tasks` holds that the ledger does not mention.

Each `task.json` carries a copy of its own task's state, because that is what
`scripts/generate-wiki.sh` reads. `rosetta sync` writes it from the ledger, so don't edit the
status by hand. The tags and the interest score are the opposite: written by hand, and read by
nothing but the index.

## tags and the index

`index.json` lists every task for [ghul.dev](https://ghul.dev)'s Rosetta Code explorer and the
playground. It is generated rather than committed: `.github/workflows/index.yml` regenerates it on
every push to main and publishes it as the only file on the `index` branch, which is where both
read it. CI fails a pull request whose tags or interest scores are missing or invalid:

```sh
dotnet run --project tools/rosetta -- index            # write index.json locally, to look at
dotnet run --project tools/rosetta -- index --check    # what CI runs
```

Two fields in each `task.json` are written by hand:

- `tags` - one to six tags from `TAGS.json`, most important first. Topic tags say what the task is
  about; language-feature tags name the ghūl features a reader would come to this solution to
  see, not every feature it happens to use. Adding a tag means adding it to `TAGS.json`, with its
  meaning.
- `interest` - 1 to 5, how much a stranger would want to run and change it: 5 draws a picture or
  plays a game, 1 prints a constant. The explorer opens on a random task weighted by this.

Everything else in an index entry comes from the task's files: its parts, source line counts, its
`*.png.expected` images, whether it reads standard input (`run.in` or `run.session`), and whether
the playground can run it (no `playground-unsupported` marker).

`wasm` on each part is true when the playground can run that part compiled to WebAssembly: it is
listed in `wasm-passing.txt`, and it has no `playground-unsupported` marker.
`wasm-passing.txt` names one program a line, by the part's `id` in the index, under a `#` line
giving the compiler, ghul-core, ghul-runtime and ghul-raster versions it was checked with. Those are the
versions the playground's compile service builds WebAssembly with, so the file is regenerated
whenever those move: every program is compiled with `--target wasm` against those versions, run
under Node, and listed when its output matches `run.expected` and every image it is expected to
write matches its `.png.expected` pixel for pixel. Without the file every part's
`wasm` is false.

`runs_on` on each task lists where the playground can run it: `dotnet` where any part can run
there, and `wasm` where any part runs compiled to WebAssembly. The index's `platforms` object names
and describes them. They are not tags, because they are derived rather than written in a
`task.json`, and the playground and the site compare tags to find tasks that are alike, which every
task would be on these.

One comes from the ledger as well: `ahead_of_wiki` is true for a published task whose section, as
`rosetta section` renders it now, is not the one `publish` last posted, so the site can say that
the solution it shows is newer than the one on the wiki.

## the rosetta tool

`tools/rosetta` is the ledger and the wiki client. Publishing signs in with a
[Special:BotPasswords](https://rosettacode.org/wiki/Special:BotPasswords) credential granted
**Edit existing pages** and nothing else, read from `~/secrets/rosetta-code-bot` or from wherever
`ROSETTA_CREDENTIALS` points. Edits appear in page history under the account the credential
belongs to, not as a bot of their own.

```sh
dotnet run --project tools/rosetta -- self-test         # feed the guards the damage they exist to stop
dotnet run --project tools/rosetta -- sync              # reconcile the ledger with the wiki and with tasks/
dotnet run --project tools/rosetta -- candidates 20     # tasks nothing has been decided about
dotnet run --project tools/rosetta -- show solved       # ledger entries, all or in one state
dotnet run --project tools/rosetta -- set "Zig-zag matrix" rejected needs-gui
dotnet run --project tools/rosetta -- publish --solved --dry-run # where each entry would go, and the page it would leave
dotnet run --project tools/rosetta -- publish --solved --target "Rosetta Code:Sandbox"   # a real run, written somewhere harmless
dotnet run --project tools/rosetta -- publish amb       # post one task, by slug
dotnet run --project tools/rosetta -- publish --replace amb   # replace the ghul section already there
dotnet run --project tools/rosetta -- publish --solved  # post every solved task
dotnet run --project tools/rosetta -- render-notes tasks/binary-digits/notes.md  # one file's markup
dotnet run --project tools/rosetta -- edit-page Template:Ghul_playground wiki-pages/Template-Ghul_playground.wiki "summary" --dry-run
```

`edit-page` replaces a whole page that is not a task's - the template every playground link
comes from, the language page - from a file, using the same credential. Those pages' text lives
in `wiki-pages/`, so a change to one is reviewed like any other before it is posted. It leaves a
page that already holds the text alone, and `--dry-run` shows the page before and after.

`sync` treats `tasks/` as the authority on what has a solution, and leaves alone anything only
the ledger knows - a rejection, a block. The wiki it only reads as a cross-check: a page
carrying a ghul section the ledger does not already hold as published was published from
somewhere else, so `sync` reports it and changes nothing rather than recording a publish it
cannot vouch for (if the section is ours, `adopt` records it). `sync` exits non-zero when that
happens, since it is a divergence for a person to decide.

`publish` reads the markup `scripts/generate-wiki.sh` leaves in `wiki-out/`, so generate before
publishing - `--solved` before `publish --solved`, `--out <slug>...` before publishing those
slugs. It puts the section in case-insensitive alphabetical position among the page's other
language headers, or replaces the ghul section already there. Naming one or more slugs publishes
only those, and `--solved` publishes every solved task; a run given neither is refused, because
the two mistakes are not equally cheap - publishing nothing wastes a run, and publishing
everything by accident edits a public wiki. An unrecognised option is refused too, rather than
being read as a slug that matches no task. A dry run writes the whole proposed page to
`wiki-out/<slug>.page` for reading before anything is sent.

Re-publishing an improved solution needs `--replace`, and the refusal that makes it necessary is
worth understanding before reaching for it. A replacement is refused unless the section on the
wiki is the one this repository last published, because a section that has changed since may
carry somebody else's correction, and replacing it silently throws their work away - which is
what happened to an edit on Multiton the first time this ran. The check cannot tell that case
from an ordinary local improvement, so it fires on both. What is on the wiki is written to
`wiki-out/<slug>.live`: read it against `wiki-out/<slug>.wiki` and satisfy yourself the only
differences are the ones made here, then re-run with `--replace`. A difference that came from
the wiki belongs in the repository, not in the bin.

`--target <page>` sends every write to one page instead of to the task pages. The rest of the
run is unchanged - it signs in, fetches the real task page and splices against its real language
headers - so pointing it at a sandbox exercises the whole path and leaves only the destination
untested. The ledger is not advanced by a targeted run, since nothing was published.

Before anything is sent, the spliced page is checked against the page it came from in two ways.

The first asks the page rather than the splice: every language section that was there has to
still be there, and ghul has to be one of them. This is the check that matters, and the reason it
ignores where the splice thought the section was going is that a guard built on the splice's own
reasoning shares the splice's mistakes - a placement claiming the whole page satisfies a
prefix-and-suffix comparison trivially, both halves being empty.

The second is that comparison anyway: everything
before where the section goes has to survive unchanged, and so does everything after whatever it
replaces. A splice that fails that is refused rather than saved, so a wrong answer shows up as a
task that did not publish instead of as a damaged page. A dry run applies the same checks, so
the whole batch can be cleared without an edit.

The third check is the wiki's own. Before the edit is offered for real, `action=compare` diffs
the stored revision against the text it would receive, and the run stops if that diff removes
more than the ghul section being replaced - nothing at all, for an insertion. This is the only
check the splice does not mark its own homework on, and it is the one to keep if the others ever
look redundant.

A solution may contain an external link where the task's own data calls for one, as `JSON pointer`
does. Rosetta Code answers an edit that adds a new external link with an hCaptcha when an
unregistered editor makes it, and the account this signs in as is past that threshold, so such an
edit goes through. If one is ever refused, the refusal names the captcha and the rest of the run
continues; `publish --dry-run <slug>` then writes the whole page the splice assembled to
`wiki-out/<slug>.page`, alongside what is live in `wiki-out/<slug>.current`, so the two can be
diffed and the assembled page pasted by hand rather than the section placed by eye.

The target has to be a page that already exists, because the credential is granted editing and
not creation. `Rosetta Code:Sandbox` does; a `User:<name>/sandbox` subpage keeps the noise off a
shared page but has to be created by hand once.

## licensing

The contents of this repository are MIT licensed, per `LICENSE`. Text and code posted to Rosetta
Code are additionally licensed under that site's own terms, so post only what you are willing to
license that way.

## issues

[View open issues](https://github.com/degory/ghul/issues?q=is%3Aopen+is%3Aissue+label%3Aghul-rosetta-code) or [raise a new one](https://github.com/degory/ghul/issues/new?labels=ghul-rosetta-code).
