These are constructs that compile and run, but do something that may be surprising.

A string is an ordinary object, and `==` on any object asks whether the two sides are the same object. Two literals with the
same spelling usually are, so the comparison looks right until one side is read
from a file or built at run time. `=~` compares the characters.

Two string literals separated only by white space are one literal, so a comma
left out of a list of strings joins two elements instead of failing to compile.
The comma is the fix, and reading the count is the cheap check.

`byte` is the signed type and `ubyte` the unsigned one, the reverse of .NET's
names for the same two types. Code that reads binary data wants `ubyte`.

A pipe is a cursor over its source. Reading part of it and then reading it
again carries on from where the last read stopped; it starts over only once it
has run out. Collect a pipe into a list when it is going to be read more than
once.
