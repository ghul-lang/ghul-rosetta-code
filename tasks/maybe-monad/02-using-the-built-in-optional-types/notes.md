The task allows using what the language provides, and ghūl provides a Maybe: the optional type `T?`. Unit is the implicit conversion from `T` to `T?`, which is why `show(8)` can pass an `int` where an `int?` is expected. Bind is `~>`: it skips the call when the value is absent, and it does not nest, so a function returning `U?` gives a `U?` rather than a `U??`.

`~>` is looser than a strict bind: it also accepts a function returning a plain `U` and widens the result to `U?`, so it serves as map as well.
