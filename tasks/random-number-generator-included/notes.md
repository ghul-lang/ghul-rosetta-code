ghūl has no random number generator of its own. A ghūl program uses .NET's
`System.Random`, which has two algorithms behind it, chosen by how the
generator is constructed.

`Random()`, with no seed, is seeded from the system. In a 64-bit process it uses
[xoshiro256**](https://prng.di.unimi.it/), a generator from the xorshift family
by David Blackman and Sebastiano Vigna. `Random.shared` is a thread-safe
instance of the same kind.

`Random(seed)` uses the algorithm .NET has always used for a seeded generator,
a version of Donald Knuth's
[subtractive generator](https://rosettacode.org/wiki/Subtractive_generator).
It is kept so that a seed produces the same sequence it did on earlier versions
of .NET, which is what makes a seeded run repeatable.

Neither is suitable for cryptography. For that, `Crypto.random_int` and
`Crypto.random_bytes` use the operating system's cryptographic generator.
