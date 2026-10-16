# AI Agent Guide for the ghūl Rosetta Code solutions

## Purpose

This guide is for AI agents and other automated contributors working in this repository. It holds
ghūl solutions to [Rosetta Code](https://rosettacode.org) tasks, which are written and tested here
before being posted to the wiki.

Read [README.md](./README.md) first for the layout and the workflow. Read
[GHUL.md](./GHUL.md) rather than working from what you remember of the language: the syntax is
unusual enough that a half-remembered version of it produces confident, wrong code, and the build
is where you find out.

## The wiki page is the audience

A solution here is not a test fixture that happens to be readable. It is the artefact that goes on
a public page beside implementations in fifty other languages, and it is read far more often than
it is run. So:

- Follow the task's own wording, including the parts that look arbitrary. Solving a tidier nearby
  problem is the single thing most likely to draw an objection there.
- No scaffolding. No commented-out alternatives, no unused helpers, no `// TODO`.
- Prefer idiomatic ghūl to short ghūl. If a generator, a pipe chain, a union or an `if let` is the
  natural way to express the task, use it - that is the reason for the entry existing.
- Comment only where a reader who does not know ghūl would otherwise misread the code. A comment
  explaining what the task is, or narrating the algorithm line by line, is noise.
- The test has to hold the solution to something, which is not the same as the task being
  deterministic. A task built on randomness seeds its generator, or asserts the invariant the
  task is about - a cipher round-tripping, a generated position being legal - and prints that.
  A task whose input is a remote file ships the file here instead of fetching it: a fetched
  input makes the build depend on somebody else's uptime, and silently pins a wrong answer
  when the file changes.
- A task about time, a clock, a path or anything else whose output legitimately differs from one
  run to the next is solved as the task asks, and its test judges the run with `run.check` rather
  than a captured `run.expected` - with `run.args`, `run.session` and `run.exit.expected` where
  they apply. Output that can be made the same every time still should be.

## The style guide applies here

[`STYLE.md`](https://github.com/degory/ghul-style/blob/main/STYLE.md) in
[degory/ghul-style](https://github.com/degory/ghul-style) holds the terminology, tone and
code-style rules for everything in the ghūl ecosystem that a person reads. It was written for
`ghul-examples` and `ghul-dev`, and it governs the solutions here too: they are posted to a public
wiki, and they are carried on ghul.dev as runnable examples, so a reader meets them in the same
places they meet everything else that guide covers.

Read it before writing a solution or editing this repository's prose. What it asks for most often:

- **Ordinary domain words for identifiers.** `running_totals`, `smallest_factor`, `left`, `right`.
  Not abbreviations, and not an alias that shortens a name the reader already knows - `use wl =
  IO.Std.write_line` saves eight characters and costs every reader the lookup. A single letter is
  right only where the task itself uses it, or where it is the notation the problem is stated in.
- **Its vocabulary rules**, in the repository's prose and in a solution's identifiers alike:
  *anonymous function* rather than *lambda*, *local variable* rather than *binding* for what `let`
  defines. Each rule is about a sense rather than a spelling, and the guide says how to tell.
- **Its register** for `README.md` and for anything else here a person reads: plain declarative
  sentences, the mechanism as the subject, no em-dashes.

Three of its sections do not apply, because this repository's own rules are stricter or its
programs are shaped differently:

- **Code comments.** The guide says when to comment and how; "When a solution carries words, and
  when it does not" below says when an entry here carries any, and that wins. The guide's comment rules
  apply to this file, `README.md`, and the tooling under `tools/` and `scripts/`.
- **`entry()` first, with the work in named subroutines.** That is the shape of a tour file in
  `ghul-examples`. A solution here is a program with top-level statements.
- **Its "imitate these" and "flag these" lists.** Both name files in other repositories.

`AGENTS.md` is written for agents rather than for users, which the guide exempts from its register
rules; the vocabulary rules still apply to it.

## Write ghūl, not C# with odd syntax

Most of these pages carry a C# entry, and the two languages are close enough
that a reader could get from ours to theirs by swapping keywords. When that is
true of an entry, it is showing them nothing, and there was no reason to write
it.

So, in rough order of how often it comes up:

- **Thread with `|>` and the global pipe functions.** They are global
  functions and `Pipe[T]` declares none of its own, so a chain of them either
  threads or nests, and here it threads:
  `xs |> map(f) |> filter(p) |> join()`, never
  `join(filter(map(xs, f), p), ", ")`.
- **Lean towards functions, but use the right tool.** A class earns its place
  when the task is itself about objects, when state and the operations on it
  belong together - a bitmap and its pixels, a parser and its cursor - or when
  it is otherwise plainly clearer than the alternative. What the lean is
  against is the class that carries no weight: two fields and one method where
  three functions would do is a transliteration of somebody else's entry, not
  encapsulation.
- **Prefer an expression body.** `=>` over `is` ... `si` wherever the body is an
  expression, including where that expression is an `if`, a `case`, or a block.
  Write a block expression parenthesised rather than with `val` ... `lav`: the
  two mean the same thing, and the parentheses are the spelling a reader from
  any language recognises as an expression. Where the block is the body of a
  `=>` or the right-hand side of an `=`, keep the opening paren on the same line
  as that token where practical:

```ghul
let total = (let acc mut = 0
             for x in xs do acc = acc + x od
             acc)
```

- **Open with `use default`.** It brings in `write_line`, the pipes and the collections, which is
  what almost every solution wants; name anything further on its own line after it. A `use` for
  something it already covers, such as `Collections.LIST`, says nothing and goes. Import a whole
  namespace where a solution uses more than a couple of its names, unless that collides with
  something the file already has; a name as common as `List`, `LIST`, `MAP` or `SET` is imported
  and written bare rather than reached through its namespace. Something uncommon that a solution
  names once, a static method in particular, is written with its namespace instead.
- **Reach for what has no equivalent in the language next door.** `let x = e in`
  and `assert c else "..." in` as expressions, `if let` and `while let` in place
  of a test followed by a cast, unions with `case` pattern matching in place of
  a class hierarchy and a chain of type tests, generators in place of building a
  list to return, `rec` for a recursive function literal.

None of this is a licence to be clever. A solution that reaches for a construct
it does not need is as bad as one that reaches for none of them; the point is
that where ghūl has its own way of saying something, the entry should say it
that way.

## Write a type once

The compiler infers a local variable's type from its initializer and from how the variable is
used later in the same body, and a constructor's type arguments from its arguments, from the slot
the value goes into, and from later use. So most types in a solution need not be written, and a
type that is written where inference already has it is noise a reader has to check.

```ghul
let seen = SET()
seen.add(first)               // seen is SET[int]

let counts = MAP()
counts[word] = counts[word] + 1

let total = cast(count) * 2n     // the 2n operand pins the cast
```

Where a type does have to be written, write it once, at the site that needs it:

- On the constructor (`LIST[int]()`) rather than on the local, when nothing later pins the
  element type - a list that is only printed, say. A local declared at an interface type
  (`let rows: List[int] = LIST()`) is the exception: the annotation is the point, so it stays and
  the constructor's arguments go.
- On the cast (`cast bigint(n)`) where no slot pins the target, rather than moving it to a `let`
  annotation. Where a slot does pin it - a typed initializer, an assignment, a return, an operand,
  an argument to a function with one applicable overload - `cast(n)` is enough.
- A `bigint` value from an integer literal is the literal with an `n` suffix (`1n`, `1000000n`),
  never `cast bigint(1)` or `bigint.one`. From an integer expression it is `cast(value)` where the
  slot pins it, and otherwise the constructor `bigint(value)`; a solution should use one of those
  two throughout rather than both.

Removing a type is the aim, moving it is not: a `LIST()` that only compiles once the local gains an
annotation has not gained anything, and the original spelling stays. Keep one solution consistent
with itself - `LIST[int]()` on one line and `LIST()` a few lines down, for no reason a reader can
see, is worse than either alone.

## A constructor that only captures its parameters is a primary constructor

A class or struct whose `init` does nothing but copy its parameters into members is written with a
primary constructor, which declares the same members and the same constructor in one line:

```ghul
struct POINT(x: double, y: double);

class CIRCLE(x: double, y: double, r: double): Shape is
    super(x, y);

    area() -> double => r * r * 3.14159
si
```

The forms for the cases around it:

- `init(..)` for a body that does more once the captures are done.
- `init(.., extra)` for a second constructor taking further arguments.
- `x: T private`, or naming the parameter `_x`, for state that is not public.
- `x: T field` for a real field rather than an auto-property, which is what a struct with a
  declared memory layout wants.
- `x: T init` for a parameter the constructor consumes rather than stores. A parameter whose value
  is stored is `private` or `_x`; writing `init` and then capturing it in the body says both
  things at once and means neither.

An explicit `init` stays where it does work the primary form cannot express, and where the task is
about constructors or member declarations themselves - say which in the pull request where it is
not obvious from the task. A task about reflection is not one of those unless listing the declared
members is its point, and the primary form declares the same members anyway.

## Arithmetic on a type of your own uses operators

Where a solution has vectors, points, matrices, complex or modular numbers, polynomials,
quaternions, intervals - anything a reader would write in notation - it defines the operators
rather than calling `plus(a, b)` and `times(p, k)`. A global operator works on a type the solution
did not declare, a tuple alias included:

```ghul
use Point = (x: double, y: double, z: double)

+(a: Point, b: Point) -> Point => (x = a.x + b.x, y = a.y + b.y, z = a.z + b.z)
*(p: Point, k: double) -> Point => (x = p.x * k, y = p.y * k, z = p.z * k)
```

and then `p + q * 2.0D` reads the way the mathematics does. The Unicode operator characters are
ordinary operators with sensible precedence, so a dot product is `a ⋅ b` and a cross product
`a × b` (GHUL.md, "operators"). A function can carry a non-ASCII name where that is the standard
mathematical one - `π`, `φ`, `ζ` - and every other identifier stays ASCII. A capital Greek letter
reads as non-snake-case, so `Σ` and `Γ` draw `non-snake-case-name` and need it suppressed to keep.
Keep a named function where there is no accepted symbol, and do not invent notation.

An operator declared this way is also a value, so ``points |> reduce(origin, `+)`` passes it to a
combinator by name, backtick-escaped so the operator reads as an identifier. The built-in
operators on the scalar types are instructions rather than methods and cannot be named that way,
so a fold over numbers takes a function literal, or `sum()`.

## Names a solution does not write

The pipe functions in `Ghul.Pipes` cover what a solution would reach into LINQ for, so a solution
does not name `System.Linq`. Nor `Ghul.Internal`, which holds the attributes carrying language
facts between assemblies and is not reachable from source; nor `MAYBE`, which is one of the three
carriers behind `T?` and is spelled `T?` wherever it is written.

A list of `n` copies of a value is `repeat(value, n) |> collect_mutable()`, not
`LIST[T](System.Linq.Enumerable.repeat(value, n))`; `repeat(value)`, `from(start)` and
`from(start, step)` are the unbounded forms.

## A collection is built by a pipe, not by a loop

A list whose elements are a function of what it is built from is built by a pipe ending in a
`collect_*`, not by declaring an empty `LIST` and adding to it in a `for`:

```ghul
let doubled = values |> map(value => value * 2) |> collect_mutable()
let flags = repeat(false, limit) |> collect_mutable()
```

A grid is the same shape twice, with one rule: the outer level is `map` and never `repeat`, because
`repeat` evaluates its argument once and would hand every row the same list.

```ghul
let cells = 0..rows
    |> map(_ => repeat(0, columns) |> collect_mutable())
    |> collect_mutable()
```

Filling the grid by index afterwards does not change that: how the elements get there is a separate
question from how the rows are made.

An array literal is already a `List[T]`, so `LIST(...)` around one builds a second collection to
hold the same elements: write the literal on its own where nothing mutates the value, and keep
`LIST` for a list something adds to, removes from, sorts in place or assigns by index. A type that
is written follows the same rule - a return type, parameter or field is `List[T]` where nothing
downstream mutates it, and `MAP` and `SET` give way to `Map` and `Set` on the same terms. A
function that builds its result by mutation keeps a `LIST` local and returns it as a `List[T]`,
which needs no conversion.

The loop stays where the body does more than add one element, where each element depends on the
ones already added, or where the list is being appended to rather than built.

A `for` disposes nothing it iterated, so a sequence holding a resource - a file being read a line
at a time - names its iterator and lets `let use` close it: `let use lines =
IO.File.read_lines(path).iterator`, then `for line in lines do`.

A count whose two ends are known is a range, `a..b` or `a::b`, choosing `::` where the task's
wording includes the last value. `from(start)` is for a count nothing bounds, which something
downstream ends - `take_while`, `find`, `first`, or a `take` counting results rather than
candidates.

```ghul
let eban = 1::limit |> filter(is_eban)
let first_twenty = from(1) |> filter(is_eban) |> take(20)
```

A fold that adds or multiplies is `sum()` or `product()`, and a sort into natural order is
`sort()` with no comparator. Both `sum` and `product` are global functions, so a local of either
name shadows the one being called and draws `shadowed-non-callable`: inline the expression, or
name the local for what the value is.

Swapping two values is one assignment, `(a, b) = (b, a)`, rather than three through a temporary.
Wrapping one that runs long goes after the `=`, because a continuation line opening with `(` reads
as a new statement.

## Output that has to line up is ASCII

The wiki's monospace font has no box-drawing, geometric or most mathematical characters, so a
browser draws them from a fallback font where they are not the width of a space, and columns built
from them come out ragged. Where output depends on alignment - a board, a box, a tree's guide
lines, a table - draw it in ASCII (`+--+`, `|`, `\-`, `o`, `#`), or draw a picture instead.
Non-ASCII output is fine where nothing has to line up with it.

Columns are laid out by the interpolation itself, `"{name,-12}{score,5:F2}"`, rather than by
padding a string by hand. The alignment is part of what the entry shows a reader, and the test
will not catch it changing: see "Test requirements".

## Solutions are not marked `pure`

The pipe combinators take pure functions, and most of what a solution passes them is not provably
one, so `map` and `reduce` draw `impure-function-argument`. The fix is not to mark the solution's
helpers `pure`. That warning is advice - the call it sits on is judged on its own callee either
way - and a `pure` written only to silence it puts a keyword on a public wiki page that says
nothing about the task, in a repository that does not apply it anywhere else. It is suppressed in
`Directory.Build.props`, for every task and for the aggregate project alike.

`impure-function-value` is a different warning and is not suppressed: it fires where a function
that might store is put into a slot declared pure, and something downstream is then entitled to
trust it. If one appears, fix the code.

## A precedence trap

**A shift mixed with a bitwise operator needs parentheses.** `&`, `|` and `^` bind tighter than
`<<` and `>>` in ghūl, the opposite of C, so `nibble >> (3 - b) & 1` is
`nibble >> ((3 - b) & 1)` and reads the wrong bits. It compiles clean and produces plausible
output, which is the worst way to be wrong. Write `(nibble >> (3 - b)) & 1`. Mixing a bitwise
operator with a comparison needs no parentheses and is right as it reads, since bitwise binds
tighter than relational: `flags & bit == 0` is `(flags & bit) == 0`, unlike C.

## A suspected bug is not a reason to change the solution

A solution producing unexpected output through a pipe chain is not evidence
that the pipe machinery is broken. The first step is a minimal repro outside
the solution. Most suspected bugs turn out to be the solution's own: an
exclusive `..` range that counts one element short, an operator-precedence
surprise, a misread of the task text.

When a minimal repro reproduces the problem outside the solution, it is a
compiler bug, and a Rosetta Code entry is not the place to work around one.
Raise it in degory/ghul, mark the task blocked against the issue, and move
on to the next task. Rewriting the solution as an imperative loop instead
ships the workaround to the wiki, where it outlives the bug and teaches
readers an idiom that does not exist.

This is not a ban on imperative loops. A loop is the natural shape of some
tasks and the right choice there. It is the wrong choice when a pipe chain
is the natural shape and the only reason for the loop is a bug that has not
been confirmed.

## Solutions carry no statement terminators

A statement's terminator can be left off at the end of a line, and here it always is. The line
break is the terminator. `rosetta-code.ghulproj` compiles every solution with
`--warn redundant-semicolon`, so a root `dotnet build` reports a stray `;` wherever it is. Nothing
else does - CI builds each task through its own project, and those do not carry the flag - so run
that build before opening a pull request.

```ghul
use IO.Std.write_line

binary(value: int) -> string =>
    if value < 2 then "{value}" else "{binary(value / 2)}{value % 2}" fi

for value in [5, 50, 9000] do
    write_line(binary(value))
od
```

Two statements on one line still need the `;` between them, and so does a statement that ends on a
string literal followed by one that begins with one - without it the two literals chain into a
single literal across the line break. Both are rare enough in a solution that meeting one is a
reason to look at the line again. `GHUL.md`'s "statement terminators" section has the rules that
keep a wrapped expression unambiguous; the ones that come up here are that a continuation line
opens with `.` or `|>`, and that a wrapped operator expression carries the operator at the end
of the line rather than the start of the next.

## Keep lines narrow

A solution is read in a column, not in your editor: on Rosetta Code it sits in a fixed-width block,
and on ghul.dev it sits in a prose column narrower than that. A line that runs past the edge either
wraps in the middle of an expression or scrolls out of sight, and neither reads well.

**Aim for 64 columns. Never exceed 76.** Those come from where the code is read rather than from
habit. ghul.dev renders an example in a prose column about 77 characters wide at the size it uses,
so a line past that scrolls out of sight - and the examples written for that site sit well inside
it, 99% of their lines at 68 columns or less. The usual 80 and 100 are already too wide here.

```sh
scripts/check-width.sh            # every line over the limits, worst first
```

The compiler's formatter can do the wrapping where an expression is simply long. `--format-width`
gives it the column to wrap at, since it targets 100 by default, and `--format-in-place` rewrites
the file rather than printing to standard output:

```sh
dotnet ghul-compiler --format --format-width 76 tasks/<slug>/<slug>.ghul
```

Both flags need `--format` alongside them; on its own, `--format-width` sets a width for a run that
then does not format anything.

**Its output carries statement terminators**, which this repository's sources do not
(degory/ghul#2298), so it cannot be used unattended here: strip them from what it produces before
keeping it. Read the result in any case - the formatter is faithful but it is not the author, and a
solution's line breaks are often deliberate.

Where a line is long because of what it says rather than how it is laid out, break it up: a local
variable for a sub-expression usually reads better than a continuation, and a long string of
output is better built than written out.

## Reaching shared state from a function

A solution with no `namespace` runs its top-level statements as the entry point,
and a `let` written there is visible to whatever is written below it: the
statements that follow, and the named functions declared after it. A function
written above the `let` it reads is an error, `global variable ... is used
before its declaration`, however late it is called, so a helper that reads one
goes below it.

```ghul
let rows = ["one", "three", "seventeen"]

widest() -> int =>
    rows |> reduce(0, (w, r) => if r.length > w then r.length else w fi)

write_line("{widest()}")
```

A bare `let` cannot be reassigned anywhere; a `let ... mut` can be reassigned
from later statements and from functions alike. Prefer the bare form and mutate
what it holds - a list, a map - rather than reassigning it, so nothing in the
file is written from two places.

A top-level `let ... mut` is the right shape when the state genuinely belongs
to the program: a counter the whole run advances, a seed the next draw reads.
These are short, often imperative programs, and a global that the program is
about is not a smell.

What to avoid is hoisting one function's working data up there so that a named
function can reach it without being passed anything. Passing what a function
needs as an argument is usually shorter, and always clearer.

The case that tempts hardest is a helper that has to carry state from one call
to the next - a cursor into a buffer. It belongs inside the function whose state
it is: a named function written among that body's statements is a local like
any other, and a `let ... mut` is captured by reference, so the helper reads and
writes the enclosing function's own state directly. A function literal in a
local variable is the same thing spelled another way.

```ghul
read_ppm(path: string) -> BITMAP is
    let raw = IO.File.read_all_bytes(path)

    let at mut = 0

    token() -> string is
        let from = at

        while at < raw.count /\ !space(raw[at]) do
            at = at + 1
        od

        return string(
            (from..at)
                |> map(index => cast char(raw[index]))
                |> collect()
        )
    si

    assert token() =~ "P6" else "not a binary PPM"
si
```

The cursor stays where it belongs, and nothing outside `read_ppm` can reach it.
A helper that needs no state of its own is a global function taking what it
reads as an argument, as `space` is here.

Where the state and the operations on it are the subject rather than a detail
of one function - a bitmap that is filled, written and read back - a class says
so more plainly than either, and is the right answer. The preference for
functions is a lean, not a rule; see "Lean towards functions" above.

## When a solution carries words, and when it does not

Most solutions carry none, and that is the shape a reader of the wiki expects.
When a reader would be left with a question, the first three answers are not
words at all, in this order:

1. **Fix the solution**, where the question is that it does something other
   than the task asks.
2. **Make the code say it**, where the question is a trick: rewrite the
   expression or rename the thing so it carries its own meaning.
3. **Retire or rework** a solution that does not really answer the task.

Only then:

4. A **note before the source**, `notes.md` beside it, for a general fact about
   the whole solution that a reader will recognise when they reach the code.
5. A **comment at a line**, for something local to that line.

What earns either:

- What the ghūl language is doing, where that is interesting or opaque to a
  programmer coming from another language and matters to the task. This is the
  main legitimate case. It states what happens; it never justifies or
  apologises for the language.
- A design choice of the program that a reader would otherwise have to infer:
  why a measurement is taken over a quarter of a swing, why a puzzle is
  shuffled by playing legal moves backwards. A few words.
- An explanation the task itself asks for. It has to carry the key fact rather
  than gesture at it, and the fact has to be taken from the code.

What does not:

- **Mathematics.** This is a site about programming languages. A reader either
  knows the mathematics and needs nothing, or does not and does not care. A
  note that would surprise a competent mathematician is the only exception.
- **The task restated**, the code narrated, or a standard technique named.
- **A fixed seed.** Everyone knows that seeding makes a run reproducible.
- **Jargon** that leaves the reader no wiser.
- A comment that **apologises for the language**. An entry that needs one
  should not be posted: park the task against the issue instead.

Everything here goes on a public wiki under the account of the person who posts
it, so anything written has to be something they could defend by pointing at
the code beneath it. Write plainly: a fact or a reason, never a sale. A value
comes from a computation rather than being read off one, and nothing
"leverages" anything. Mathematical notation is not neutral either: `a^b` reads
as the xor operator, so write what the code spells.

## Tasks that are not solved

Cryptocurrency tasks are not solved. Reject them.

## Adding a task

```sh
scripts/new-task.sh <slug> "<Rosetta task title>"
```

Then write the solution, run it, and capture the output:

```sh
dotnet run --project tasks/<slug>
dotnet ghul-test tasks/<slug>
scripts/capture.sh tasks/<slug>
```

Read the produced output before capturing it. `capture.sh` turns whatever the program printed into
the permanent expectation, so capturing without reading is how a wrong answer gets pinned as
correct.

Then record it in the ledger:

```sh
dotnet run --project tools/rosetta -- sync
```

`ledger/` is the authority on what has been done and what has been decided against. Never
edit a `task.json` status by hand - `sync` writes it. `sync` records the tasks in `tasks/` as
solved, but it never writes `published`: a section on the wiki that this ledger did not publish
came from another run of the repository, and `sync` reports those and exits non-zero rather than
adopting them, because a publish recorded without its hash is what makes a page unpublishable
later. When a task turns out not to be worth
doing, say so once and for all rather than leaving it to be reassessed:

```sh
dotnet run --project tools/rosetta -- set "Animate a pendulum" rejected needs-gui
```

The reasons are a fixed set - `needs-gui`, `needs-network`, `needs-interaction`,
`nondeterministic`, `needs-native-lib`, `output-unbounded`, `no-equivalent`, `excluded`,
`task-unclear` - and `blocked` is the one state that
comes back: it names a compiler or runtime issue and is retried when that closes.

`no-equivalent` is for a task that asks how the language spells a feature it does not have - a
topic variable, a macro, a nested type. The only honest wiki entry is a sentence saying the
language has no such thing, and a sentence of prose is not what a solution here is.

`excluded` is for a task this repository does not solve.

Four of the reasons are narrower than they read. `nondeterministic` is for a task whose output no
check can judge, rather than one that merely varies from run to run: a varying output is asserted
with `run.check`. `needs-native-lib` is for a library .NET does not have, not for calling into
one: a shared library is reached with `DllImport` on a bodyless static, so a task whose point is
that call is solvable. `needs-interaction` is for a task with no
output worth reading rather than one that prompts: a prompting program is driven by `run.session`
and a program reading a stream by `run.in`. `needs-network` is narrower still: a task whose point is
talking to a service is solved against a stand-in for it, as below, and the reason is left for one
where the live data or the particular machine is the whole of the answer.

### A task that talks to a service

A client for HTTP, HTTPS, SMTP, DNS, FTP, SOAP or a web API is published against the real service,
and tested against a stand-in the published code never mentions. `tasks/https` is the model:

- `tasks/<slug>/<slug>.ghul` is the only file the wiki gets, so it is the task alone: the client in
  a function that takes whatever a stand-in has to replace (an endpoint, an `HttpClientHandler`, a
  resolver's answer), and top-level statements that call it with the real service, the one the
  task names or the other entries use. No argument selects anything test-shaped.
- `tasks/<slug>/stand-in.ghul` holds the stand-in and an `@entry()` function, `test_entry`, that
  starts it on the loopback address, on a port the system picks, and calls the published
  function against it. The test runs that entry, so its output is the same on every run and
  needs no network.
- The project sets `GhulGlobalNamespace` so the two files share names, and
  `GhulNoWarn` to `top-level-statements-not-run`, since under the test the published file's
  top-level statements are not the entry.
- A TLS stand-in makes its certificate for the run and passes a handler that trusts that one
  certificate by thumbprint. Nothing accepts any certificate.
- A stand-in for a web API answers from a recorded reply shipped with the task, whose first line
  names the date it was captured.
- `tasks/<slug>/wiki-output.txt` is a run of the published file against the real service,
  recorded by hand, and `scripts/generate-wiki.sh` shows it in place of the test's output, which
  is the stand-in's answer. A long run is trimmed with an ellipsis. Where the service cannot be
  reached from here, or needs an account (sending email), there is no recording.
- `dotnet run --project tasks/<slug>` runs the test's entry, the stand-in. To run the published
  file against the real service, compile that one file on its own, with no project, and run it.
- The task carries `playground-unsupported`: the playground has no sockets.

A rejection can also be reversed, when what made the task impossible stops being true. That is
`reopen`, and it takes the reason for the reversal rather than being a bare undo:

```sh
dotnet run --project tools/rosetta -- reopen "100 prisoners" "seeded, and the ~31% answer is the point"
```

The verdict being overturned is written into the entry's note, so a later run reads why the old
reason no longer holds instead of re-reaching it. Reopening without saying what changed just
sets the task up to be rejected again.

## Explanatory text

A note before the source is written as Markdown in `tasks/<slug>/notes.md`, or
beside a part's source for a task with parts: paragraphs, `#`/`##` headings,
bullet and numbered lists, `**bold**`, `*italic*`, `` `code` `` spans and
`[text](url)` links are the supported subset. `scripts/generate-wiki.sh` converts it to wiki markup and
places it ahead of the code. Render it on its own and read the result before
doing anything else with it:

```sh
dotnet run --project tools/rosetta -- render-notes tasks/<slug>/notes.md
```

**Show the user the rendered text and get it read before the branch is raised
for merge, and do not arm auto-merge on it.** The code in a task is covered by a
captured test; the prose is not, and unlike the code it makes a claim to the
reader rather than an assertion the test can check automatically. Follow
`raise-pr` as usual to open the pull request, but stop short of the auto-merge
step `land-pr` would otherwise arm immediately, and say plainly that the PR is
waiting on a person because it carries prose. This is independent of
publishing, which is already gated on an explicit request from the user -
README.md's 'writing explanatory text' has the detail.

## A command line a reader sees

A task the program takes arguments from carries them in `run.args`, one argument a line, and the
test runner starts it with them. The playground reads the same file, shows the arguments as a
command line, and lets a visitor edit it before running the task, so the line has two audiences:
it is an assertion and it is an example.

Write a command line worth reading rather than only one worth asserting. Command-line arguments
passes `first`, `second argument`, `--flag` and `last`: a visitor sees a line somebody might type,
and the space in the second still shows what quoting is for.

The playground quotes an argument containing whitespace or a quote, escaping either with a
backslash, so a line with a space in it means the same thing in both directions. The file itself
stays one argument a line.

## Running in the playground

Every entry links to the solution in the ghūl playground, which fetches the source from this
repository and runs it in the reader's browser. It compiles one source file against the ghūl
runtime, `ghul.raster` and the parts of .NET that work in a browser, reads standard input from a
box under the output, shows the images a program draws, runs threads, and holds the files a task
ships in a filesystem of its own. What it rules out is the network, a child process,
`Environment.exit` and a second source file. Deciding whether a solution needs one of those takes
reading it, so it is part of writing it: a program that cannot run there carries a
`playground-unsupported` file beside its source, one line saying why, written for the reader who
opens the link anyway. `scripts/generate-wiki.sh` writes no link for it. The link itself
transcludes the wiki's `Template:Ghul playground` and passes only the program's path, so the
wording is the template's rather than each entry's. README.md's 'running a solution in the
playground' has the detail.

A long run is not by itself a reason to withhold it. What a visitor cannot read is a page that
sits there saying nothing, and a program that says what it is doing may take as long as the task
needs. The playground runs five to ten times slower than the same program does natively, so:

- Under about three seconds natively, a solution needs nothing. The figure is the silence budget
  divided by the worst of that ten: what matters is not the number but whether someone could be
  left looking at a blank box for more than about half a minute.
- Over that, it prints something as it goes, and keeps printing: a line before the work saying it
  will take a while, a line per step, a count against an estimated total. That output is part of
  what the test captures, so it has to be the same on every run - a line per item rather than a
  timer. A figure that genuinely varies, an elapsed time among them, is allowed where a
  `run.check` asserts the part that does not vary and only that the rest was reported;
  `pi-to-1-million-digits` does exactly that.
- `playground-unsupported` is for what genuinely cannot run there: the network, a child process,
  a filesystem, memory the browser will not give, or more than about a minute natively, which is
  ten minutes there even with the progress showing.

Thirty seconds of silence is the most a page should ever ask of someone; several minutes of
visible progress asks nothing at all.

## Publishing, and the record of it

```sh
scripts/publish.sh <slug>...      # or --solved, for everything not yet on the wiki
```

That one command generates the markup, makes the edits, commits the digests the run wrote into
`ledger/`, pushes, and opens the pull request. Do not run `rosetta publish` directly, and do not
publish and leave the record to be committed afterwards.

The digest is the whole reason. `publish` writes each page's new digest into the ledger as it goes,
and a later run compares the live section against it to tell an edit somebody else made from one of
ours: a section whose digest is not the recorded one is refused rather than overwritten. A record
that never reaches `main` therefore does not merely go missing. It leaves every page it covers
unpublishable, and the refusal that follows months later reads as though a stranger had edited a
hundred pages at once.

The pull request needs nothing from anybody. `.github/workflows/ledger.yml` approves a change that
touches only `ledger/` and `tasks/*/task.json`. `scripts/publish.sh` arms auto-merge when it raises
the pull request, and it merges when the shards pass. The workflow cannot arm it itself: a merge
made with a workflow's own token starts no workflow, so the push to `main` would go untested.
That path test is the whole distinction between what lands unread and what does not, so a
ledger-only pull request must carry nothing else - not a compiler pin, not a recaptured
expectation, not a solution. Raise those separately.


## Showing a task more than one way

A task worth showing two ways - the library call, and the same thing written out - is held as
parts: `tasks/<slug>/NN-name/`, each a whole program with its own project and its own test, each
becoming one `===heading===` section of the entry. `scripts/new-part.sh <slug> <NN-name>` scaffolds
one. `README.md` has the layout.

Reach for it when the two ways are genuinely different things a reader would want to see side by
side. A solution that prints several results is one part, not several.

## Test requirements

The integration tests must pass before a pull request merges. They are what CI runs, and they
build each task as they go.

| Step | How to run | Typical duration |
|------|-----------|------------------|
| One task's test | `dotnet ghul-test tasks/<slug>` | seconds |
| Integration tests | `dotnet ghul-test tasks` | minutes |

Locally, run the tests for the tasks you created or edited, and no others: name them on one command
line (`tasks/<slug-a> tasks/<slug-b>`). A new task has to be run anyway to capture its expectation,
and an edited one to show it still passes. A task nobody touched cannot have changed, and CI runs the
touched tasks on every pull request and every push to `main`, and the whole suite whenever
something outside the tasks changes (`scripts/tasks-to-test.sh` decides), so adding solutions
never calls for running all of them. Whether
to run the whole suite, or a subset, is a judgement call only when something every task depends on
has changed: the compiler or runtime version, `Directory.Build.props` or `Directory.Packages.props`,
the test runner or how the tests are run, or a shared script.

A root `dotnet build` type-checks every solution in one pass and is the only thing that reports a
stray statement terminator, so it is worth running, but it produces none of the programs - see
"The root project" below. Build and run a single task with `dotnet run --project tasks/<slug>`.

- Each task directory is its own test case: the `ghulflags` and `*.expected` files sit beside
  the source. `scripts/new-task.sh` and `scripts/new-part.sh` scaffold them.
- Tests assert the program's output. There are deliberately no IL snapshots - a test folder with
  no `il.expected` has its IL ignored, and `capture.sh` will not create one.
- **The output comparison ignores changes in whitespace.** `run.expected` is diffed with `-b`, so
  a change to how columns line up passes a test that was captured before it, and `capture.sh`
  then has nothing to promote. Read the run, and where alignment is the point write the file
  rather than relying on a capture to notice.
- Which file a test asserts with depends on what the program does: `run.expected` for output that
  is the same every time; `run.check`, an executable judging `run.out` and passing by exiting
  zero, where it is not; `run.err.expected` for what the program wrote to standard error;
  `run.exit.expected` where a non-zero status is the subject, since without it any non-zero status
  fails; `run.args` for a command line; `run.in` for input sent and the stream closed;
  `run.session` for a program that prompts, answered a line at a time and echoed into the
  transcript; `<name>.png.expected` for an image, compared by bytes and then by pixels. A test
  carrying both `run.in` and `run.session` fails.
- A compiler pass that throws writes an `exception:` line, and a test whose compiler output holds
  one fails on that alone, whatever it asserts.
- A failing test is your change. This repository's tests are pinned to output that was read and
  captured deliberately, so a failure means either the solution changed or the compiler did. Find
  out which before touching an expectation file.

## The root project

`rosetta-code.ghulproj`, with `root/entry.ghul`, names every task's source so the ghūl VS Code
extension loads them in one analysis session.

**It builds, and it produces none of the programs.** Every task carries its own top-level
statements, so an aggregate of them all has no single entry point to run: the project takes
`OutputType` `Library` and an `--entry root_entry` stub, and suppresses the
`top-level-statements-not-run` warning each task would otherwise draw. What the build is good for
is type-checking every solution at once and reporting stray statement terminators. CI does not run
it - each task is built by its own test project.

Don't try to make the tasks build together as programs by wrapping solutions in an `entry()`
function. A task's source should read the way it will read on the wiki, and top-level statements
are the reason a ghūl entry there needs no wrapper at all.

## Keeping GHUL.md in sync

`GHUL.md` is not authored here. The master copy is `GHUL.md` in the
[`ghul`](https://github.com/degory/ghul) compiler repo. Refresh the copy here when it has fallen
behind and you are already touching this repository; never hand-edit it to correct a language
reference error, fix it in the compiler repo instead.

## See also

- [README.md](./README.md) - layout and workflow
- [GHUL.md](./GHUL.md) - language reference
