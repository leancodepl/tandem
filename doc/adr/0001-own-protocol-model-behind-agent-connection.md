# Own AG-UI protocol model behind `AgentConnection`, no dependency on `ag_ui`

## Decision

Tandem's core has its own small model of the AG-UI wire format (run input, messages, events) and talks to an agent only through the `AgentConnection` seam, with `HttpAgentConnection` (HTTP + SSE) and `ScriptedAgent` for tests.

## Why not `ag_ui`

The community `ag_ui` Dart package (0.3.0, 2026-06-24) is the only Dart SDK listed by AG-UI. We did not build on it because:

- its client turns the first unknown event type into a stream error,
- it drops AG-UI 1.0 fields such as `RUN_FINISHED.outcome`,
- it cannot cancel a run once response headers arrived,
- it never sends the `runId` that ag-ui-adk requires,
- it exports a `State` typedef that clashes with Flutter.

## When to reconsider

When a Dart SDK has none of these limits. A first-party AG-UI 1.0 Dart SDK was proposed upstream on 2026-10-15 and closed the same day, so the landscape may change. Adopting or collaborating on a package makes it one more `AgentConnection` adapter, and nothing else in Tandem changes.
