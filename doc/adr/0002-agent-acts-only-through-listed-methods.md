# The agent acts only through the methods a screen lists

## Context

An agent that writes a shared state makes Tandem diff and patch it, and tell the user's edits from the agent's writes by content. That is a lot of code and a source of subtle bugs. Such an agent also skips the validation the screen's buttons run.

## Decision

The agent never writes state. It sees the values listed with `.sees`, as AG-UI `context`, and acts only by calling methods listed with `.calls` and `.callsWithApproval`. These are the methods the buttons call, so the same validation applies to both.

The list is read again before every run and before every call. A method that left the list, or needs approval by then, is refused and does not run. An approval covers what the agent sees when it asks. Approve checks the live list again, and a change to `.sees` after the agent asked invalidates the request for good.

`context`, not `state`: ag-ui-adk keeps state in its session, so an old value stays when a later run does not send it.

## Consequences

- Whatever the agent should change needs a listed method. Whatever a method with approval depends on must be in `.sees`, or the approval does not cover it.
- The list is read by generated code, so `.sees` must stand directly in the list and the code must be generated again after the list changes.
- The backend has to put `context` into the model's prompt itself.
