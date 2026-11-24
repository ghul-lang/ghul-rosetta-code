ghūl has no random number generator of its own. A ghūl program uses
`Ghul.Random`, which has two algorithms behind it, chosen by how the
generator is constructed.

`Random()`, with no seed, is seeded from the system and uses
[xoshiro256**](https://prng.di.unimi.it/), a generator from the xorshift
family by David Blackman and Sebastiano Vigna. `Random.shared` is a
thread-safe instance of the same kind.

`Random(seed)` uses a subtractive generator, a version of Donald Knuth's
[subtractive generator](https://rosettacode.org/wiki/Subtractive_generator).
A seed produces the same sequence every run, which is what makes a seeded
run repeatable.

Neither is suitable for cryptography. For that, `Crypto.random_int` and
`Crypto.random_bytes` use the operating system's cryptographic generator.