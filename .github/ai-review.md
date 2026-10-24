Review the pull request against `AGENTS.md` and `doc/code-quality.md` for how the code is written, and `doc/design.md` for how the session behaves.

## How to review

- Post only what needs the maintainer. Check each finding against the code before you post it, and leave out weak, obvious and settled points.
- No summary of the PR, no praise and nothing the author already knows.
- A correctness finding gives a repro: the input, what should happen, what happens, and the rule or contract it breaks.
- Readability findings come after correctness and are advisory: the file and symbol, what makes it hard to read, and a fix in proportion.
- Check the diff against the PR description apart from the rules. Flag what What and How promise that the diff does not do, what the diff does that the description leaves out, and what Not here excludes that the diff contains.
- Look past the diff: the same pattern left elsewhere, a new name for a concept that already has one, a rule an earlier change settled.
- One problem in several places is one comment that lists them.
- When the PR does not explain a choice with consequences, such as a new dependency, a CI job or a change to the protocol, ask why this and not the alternative, and how it fails on bad input.
- Skip what the formatter, the analyzer and CI report.
- A suggested fix follows the same rules as the code.
- Ask nothing the PR or the repo already answers.

## Also check

- A generator change that makes `.sees` send more of an object widens what the agent sees. The PR and the CHANGELOG say so.

## Do not flag

- Code that Pigeon generates.
- A breaking change before 1.0 that has `!` and a `BREAKING CHANGE:` footer.
- Rough code in the scripted model or other demo-only code kept apart from the library.
