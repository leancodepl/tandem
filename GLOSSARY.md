# Tandem

Tandem makes an existing Flutter screen agent-aware: an agent and the user work on the same screen, and the agent acts only through methods the screen lists.

## Language

**Agent list**:
The `agentCapabilities` getter of a cubit with `@TandemAgent()`: what the agent sees and which of the cubit's methods it may call. It is read again before every run and before every call.
_Avoid_: shared state, state host

**Capability**:
One item of the agent list: `.sees`, `.calls` or `.callsWithApproval`.
_Avoid_: permission, grant

**Session**:
One conversation between a screen and the agent, from opening the screen to closing it. AG-UI calls it a thread.
_Avoid_: thread, conversation

**Run**:
One turn of the agent: a single request to the agent backend and the events it streams back.
_Avoid_: request, call

**Tool**:
A method of the cubit that the agent may call, listed with `.calls` or `.callsWithApproval`. It runs in the app, and `onAgentCall` reports it afterwards.
_Avoid_: client tool, action, command, agent marks

**Approval request**:
The agent's call of a `.callsWithApproval` method, shown as a card with its arguments frozen. The method runs only after the user approves it.
_Avoid_: confirmation, interrupt

**Invalidated**:
The state of an approval request when what the agent sees changed after the card showed. It can no longer be approved.
_Avoid_: stale, expired, outdated

**Stop**:
The user's end of a run. The run is still read to its end, but its later text is hidden and none of its remaining calls runs.
_Avoid_: abort, disconnect

**Chat**:
What the user sees of a session, in order: messages, notices and approval requests.
_Avoid_: timeline, history, transcript
