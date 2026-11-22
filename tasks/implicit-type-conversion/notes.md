ghūl converts a number implicitly only to a wider number:

- `int` to `long`, `single`, `double`, `bigint` and `complex`
- `long` to `single`, `double`, `bigint` and `complex`
- `single` to `double` and `complex`
- `double` to `complex`

The conversion happens in arithmetic, at a call argument, in a typed `let`, an
assignment and a return, and where the arms of an `if`, or the elements of an
array literal, are numbers of different types. Nothing narrower than `int`
widens, and nothing widens to `decimal`.
