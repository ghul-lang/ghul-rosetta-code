In ghūl the case of a name says what kind of thing it names, and the compiler
checks it:

- `snake_case` for variables, functions, methods and properties.
- `PascalCase` for namespaces, traits, abstract classes, unions and enums.
- `UPPER_SNAKE_CASE` for union variants and enum members.

Concrete classes and structs may use either `PascalCase` or `UPPER_SNAKE_CASE`.
The library's own types use `UPPER_SNAKE_CASE`, so `LIST[int]` reads as a
library type and `Point` as one of yours.

A `static` field or property reads as a named constant, so it can be written in
either `snake_case` or `UPPER_SNAKE_CASE`. Keywords are all lowercase.

There are no `public` or `private` keywords. A name that starts with an
underscore is private: by default a member such as `_count` can be used only
inside the class that declares it, and a type or global function can be used only inside
its own assembly. The compiler reports an error for a use from anywhere else.

A declaration in the wrong case is reported as a warning rather than an error.
Each rule has its own warning, `non-snake-case-name`, `non-pascal-case-name` and
`non-upper-snake-case-name`, and each can be suppressed for one declaration or
one file with `@suppress`, or for a whole project with `--suppress`. The program
below declares three names in the wrong case, and the compiler reports one
warning for each:

- `non-UPPER_SNAKE_CASE enum member 'north'`
- `non-PascalCase trait 'drawable'`
- `non-snake_case name 'CountItems'`

Names imported from .NET are read in the same conventions. Method, property and
field names become `snake_case`, so `DateTime.DaysInMonth` is called as
`DateTime.days_in_month`, and enum members become `UPPER_SNAKE_CASE`. Class,
struct and interface names keep their .NET spelling, apart from a few common
types that are renamed: `IEnumerable<T>` is `Iterable[T]`. An identifier that
is also a ghūl keyword is written with a leading backtick.
