# TODOs

- [ ] Make the directive comment could take multiple arguments [1]
- [ ] The cli currently derive everything that is in directive comments, it needs to respect the cli flags (`-d`)

[1]: currently it only take one: `// my-type.derive(show)`. I want it to be able to do: `// my-type.derive(show, eq, ...)`
