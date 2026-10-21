The [ghul CLI tool](https://github.com/ghul-lang/ghul-cli) provides the `ghul` command the
shebang names, and is itself written in ghūl. It compiles the script on first run, caches
the binary, and only recompiles when the script or the compiler changes, so what runs on
every later invocation is the cached native binary.
