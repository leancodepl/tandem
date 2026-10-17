# The agent acts only through the methods a screen lists

## Context

[leancodepl/tandem#1](https://github.com/leancodepl/tandem/pull/1) gave the agent a shared state it could write. Tandem diffed and patched it, and told the user's edits from its own writes by content. That was half of the code and the source of its worst bugs. An agent that writes state also skips the validation the screen's buttons run.

## Decision

The agent never writes state. It sees the values listed with `.sees`, as AG-UI `context`, and acts only by calling methods listed with `.calls` and `.callsWithApproval`. These are the methods the buttons call, so the same validation applies to both.

The list is read again before every run and before every call. A method that left the list, or needs approval by then, is refused and does not run. An approval covers what the agent sees when it asks. Approve checks the live list again, and a change of what the agent sees invalidates the card for good.

`context`, not `state`: ag-ui-adk keeps state in its session, so an old value stays when a later run does not send it.

## Consequences

- [ADR 0002](0002-attach-to-the-apps-state-host.md) and its shared state are superseded.
- Whatever the agent should change needs a listed method. Whatever an approval card shows must be in `.sees`, or the approval does not cover it.
- The list is read by generated code, so `.sees` must stand directly in the list and the code must be generated again after the list changes.
- The backend has to put `context` into the model's prompt itself.
