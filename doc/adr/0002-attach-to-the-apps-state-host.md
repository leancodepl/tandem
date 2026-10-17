# Tandem attaches to the app's state host instead of owning the shared state

Superseded by [ADR 0003](0003-agent-acts-only-through-listed-methods.md).

## Decision

The shared state stays in the state holder the screen already has, usually its cubit, which gains one `with AgentEditable<S>` clause. Tandem reads it, listens to it and writes the agent's changes into it.

## Why

The obvious design is a session that owns a typed shared state. With it, every existing screen has to move its form onto the session or keep two copies in sync, which defeats the goal of making an existing screen agent-aware with a few lines.

## Consequences

- Tandem tells the user's edits from its own writes by content, so `StateCodec.encode` must be deterministic.
- Conflicts are resolved per leaf: last write wins, compared with what the agent already knew. Without that, ag-ui-adk would revert edits the user made during a run, because it restates the run-start state in a snapshot at the end of every run.
