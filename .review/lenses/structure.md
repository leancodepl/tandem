## Lens: code that is hard to read

Principles 2, 3 and 4 of `doc/code-quality.md` are the rules: keep a flow at one level of detail, make decisions easy to follow, make names and call sites explain intent. Agents write code that is correct and dense; the maintainer rejects it when a reader has to hold too much in mind to follow it, even with green tests.

Read every function, method and getter the change adds or grows, and every new file, as the maintainer reading the diff for the first time. Report it when:

- An entry point that does not read as a few named steps because parsing, rendering or diagnostics detail sits inline (principle 2).
- State a reader must track: several mutable locals, or a value computed in one branch and patched in another.
- Decisions are nested more than two levels deep, chained `if`/`else if` encode several unrelated conditions, or a guard that could return early wraps the rest of the function.
- Dense expressions: long `??` or ternary chains, collection `if`/`for` inside arguments, casts and pattern matches that do several things in one line, unnamed magic numbers.
- A name says less or other than what the code does, or a predicate promises more than it checks.

For each, name what makes it hard to read and a fix in proportion: the steps to extract and their names, the early return, the type that removes the bookkeeping. Leave out code that is long but plain.
