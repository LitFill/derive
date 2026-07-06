# TODOs

- [ ] Make the directive comment could take multiple arguments [1]
- [ ] The cli currently derive everything that is in directive comments, it needs to respect the cli flags (`-d`)
- [ ] Make the --verbose flag receive int instead of only bool, also add --quiet (?) [2]

[1]: currently it only take one: `// my-type.derive(show)`. I want it to be able to do: `// my-type.derive(show, eq, ...)`
[2]: so we can distinguish between verbosity levels like info, warn, debug, error, etc.
