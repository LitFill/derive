# TODOs

- [P1] Make the directive comment could take multiple arguments [^1]
       add space between generated functions
- [P2] The cli currently derive everything that is in directive comments, it needs to respect the cli flags (`-d`) [^3]
- [P4] Make the --verbose flag receive int instead of only bool, also add --quiet (?) [^2]
- [P3] cannot parse `pub {type|struct}`
- [  ] add more typeclasses (add, multiply, substract, divide, compare or cmp, map or functor, map2, mapN eg. mapN(1 to 10), ...)
- [  ] Koka's newtypes support is lacking, maybe we could help it with derive? eg. annotation // derive:newtype or smth?

[^1]: currently it only take one: `// my-type.derive(show)`. I want it to be able to do: `// my-type.derive(show, eq, ...)`
[^2]: so we can distinguish between verbosity levels like info, warn, debug, error, etc.
[^3]: if the derive directive comments use multi typeclass syntax, eg. `mytype.derive(eq, show, add)`, and `-d` only wants `show`, then the directive comment should be changed to `mytype.derive(eq, add)`.
