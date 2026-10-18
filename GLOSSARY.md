# Tandem

Tandem makes an existing Flutter screen agent-aware: an agent and the user work on the same screen, and the agent acts only through methods the screen lists.

## Language

**Surface**:
The state object of a screen that the agent works on, of a class with `@TandemAgent()`: a Cubit, a Riverpod `Notifier`, a `ChangeNotifier` or any class that reports its changes. A screen has one.
_Avoid_: cubit (for any surface), model, controller

**Agent list**:
The `agentCapabilities` getter of the surface: what the agent sees and which of the surface's methods it may call. It is read again before every run and before every call.
_Avoid_: shared state

**Capability**:
One item of the agent list: `.sees`, `.calls` or `.callsWithApproval`.
_Avoid_: permission, grant

**Session**:
One conversation between a screen and the agent, from opening the screen to closing it. AG-UI calls it a thread, and a run that breaks off moves the session to a new one.
_Avoid_: thread, conversation

**Run**:
One turn of the agent: a single request to the agent backend and the events it streams back.
_Avoid_: request, call

**Tool**:
A method of the surface that the agent may call, listed with `.calls` or `.callsWithApproval`. It runs in the app, and `onEvent` reports it afterwards as an `AgentCall`.
_Avoid_: client tool, action, command

**Approval request**:
The agent's call of a `.callsWithApproval` method, shown to the user as a card or a dialog, with its arguments frozen. The method runs only after the user approves it. Several in one turn show one at a time.
_Avoid_: confirmation, interrupt

**Invalidated**:
The state of an approval request when a value listed with `.sees` changed after the agent asked. It can no longer be approved, even when the value comes back.
_Avoid_: stale, expired, outdated

**Event**:
What happened in a session that the app may react to, as a `TandemEvent`: a call that returned, a stop, a failed run, a lost connection. Approval requests are not events.
_Avoid_: notification, notice

**Status**:
What a session does now: idle, thinking, calling a method, awaiting approval or stopping. It is one of these at a time.
_Avoid_: state, running, busy

**Stop**:
The user's end of a run. The run is still read to its end, but its later text is hidden and none of its remaining calls runs.
_Avoid_: abort, disconnect

**Chat**:
What the user sees of a session, in order: messages, notices and approval requests.
_Avoid_: timeline, history, transcript
