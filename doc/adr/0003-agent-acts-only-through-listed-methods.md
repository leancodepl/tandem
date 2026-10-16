# The agent acts only through the methods a screen lists

## Context

leancodepl/tandem#1 gave the agent a shared state it could write. Tandem diffed and patched it, and told the user's edits from its own writes by content. That was half of the code and the source of its worst bugs, and an agent writing state skips the validation the screen's buttons run.

## Decision

The agent never writes state. It sees the values listed with `.sees`, as AG-UI `context`, and acts only by calling methods listed with `.calls` and `.callsWithApproval`. These are the methods the buttons call, so the same validation applies to both.

The list is read again before every run and before every call: a method that left the list, or now needs approval, is refused and does not run. An approval covers what the agent sees when it asks. Approve re-checks the live list, and a change of what the agent sees invalidates the card for good.

`context`, not `state`: ag-ui-adk keeps state in its session, so an old value stays when a later run does not send it.

## Consequences

- The shared state from leancodepl/tandem#1 is gone, and ADR 0002 is superseded.
- Whatever the agent should change needs a listed method. Whatever an approval card shows must be in `.sees`, or the approval does not cover it.
- The list is read by generated code, so `.sees` must stand directly in the list and the code must be generated again after the list changes.
- The backend has to put `context` into the model's prompt itself.
