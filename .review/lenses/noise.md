## Lens: noise in code, comments, tests and docs

The rules are in `AGENTS.md`: "The code explains itself", "A doc comment says more than the name and type, or it is not written", "Few tests... No test that restates the implementation", "Docs and comments: short sentences, plain words... Say what is true, not how it came to be", and principle 1 of `doc/code-quality.md` applied to documentation. The maintainer removes text that only repeats what the code or the folder tree already shows.

Report, in what the change adds:

- A doc comment that restates the name and type of what it documents, or a comment on a private member whose name already says it.
- A comment that narrates what the next lines do, how the code came to be, or a constraint the code already states.
- A test that restates the implementation, several tests of one behaviour, or tests that grow faster than the code they cover.
- A README or doc section that lists folders or files, repeats another section, or describes the code instead of what a reader needs to use it.
- An `// ignore:` without a reason that holds, or a lint suppression the code could avoid.

Also report a change to the public API that leaves out what `AGENTS.md` says must change with it (`README.md`, the package README, `example/example.md`, the skills, `example`, `showcase`, `doc/design.md`), and a README section that a new user meets before the quick start although it is not needed to start.
