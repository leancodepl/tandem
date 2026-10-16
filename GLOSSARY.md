# Tandem

Tandem makes an existing Flutter screen agent-aware: an agent and the user work on the same thing on that screen.

## Language

**Session**:
One conversation between a screen and the agent, from opening the screen to closing it. AG-UI calls it a thread.
_Avoid_: chat, thread, conversation

**Run**:
One turn of the agent: a single request to the agent backend and the events it streams back.
_Avoid_: request, turn, call

**Shared state**:
The part of a screen's state that both the user and the agent may change, such as an order draft.
_Avoid_: agent state, store, model

**State host**:
The object in the app that owns the shared state, usually the screen's existing cubit. Tandem writes into it but never owns it.
_Avoid_: store, state holder

**Tool**:
A function of the app that the agent may call. It runs in the app.
_Avoid_: client tool, action, command, frontend tool

**Agent tool**:
A function the agent runs on its own side. The app only sees that it is running and when it is done.
_Avoid_: backend tool, server tool

**Approval request**:
The agent's proposal to call one specific tool with exact arguments, waiting for the user's decision.
_Avoid_: confirmation, interrupt

**Approval**:
The user's consent to one approval request. It is only possible while the shared state is unchanged since the proposal.
_Avoid_: confirmation, consent

**Stale**:
The state of an approval request whose shared state changed after the proposal, or during the run that proposed it, which the agent did not see. It can no longer be approved.
_Avoid_: invalid, expired, outdated

**Agent marks**:
The parts of the shared state the agent changed last, so the screen can highlight them.
_Avoid_: highlights, agent edits

**Timeline**:
What the user sees of a session, in order: user messages, agent messages, tool activity and approval requests.
_Avoid_: chat log, history, transcript
