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
One screen's time with a thread, from opening the screen to closing it, as a `TandemSession`.
_Avoid_: conversation

**Thread**:
The conversation of a screen with the agent, as a `TandemThread`: the chat, and the AG-UI thread with its messages and the agent state. The app can keep it and give it to the next session of the screen. A run that breaks off and `startOver` move it to a new AG-UI thread, and the chat stays.
_Avoid_: history

**Run**:
One turn of the agent: a single request to the agent backend and the events it streams back.
_Avoid_: request, call

**Tool**:
A method of the surface that the agent may call, listed with `.calls` or `.callsWithApproval`. It runs in the app, and `onEvent` reports it afterwards as an `AgentCall`.
_Avoid_: client tool, action, command

**Caller**:
Who called a listed method: the in-app agent, a coding agent, or the user with a press on a button of a view. `AgentCall` and `ApprovalRequest` name it as a `Caller`.
_Avoid_: source, origin

**Approval request**:
A call of a `.callsWithApproval` method by any caller, shown to the user as a card or a dialog, with its arguments frozen. The method runs only after the user approves it. Several in one turn show one at a time.
_Avoid_: confirmation, interrupt

**Invalidated**:
The state of an approval request when a value listed with `.sees` changed after the call asked. It can no longer be approved, even when the value comes back.
_Avoid_: stale, expired, outdated

**Agent state**:
What the agent's backend keeps of the thread and streams with `STATE_SNAPSHOT` and `STATE_DELTA`, as `session.agentState`. Every run sends it back. Not the surface's state.
_Avoid_: state, shared state, session state

**Note**:
A line the app gives the agent about what happened outside the chat, with `session.note`. Every run gives the agent the latest five in one `context` entry. `session.wake()` lets the agent take a turn on them.
_Avoid_: event, notification

**Event**:
What happened in a session that the app may react to, as a `TandemEvent`: a call that returned, a stop, a failed run, a lost connection. Approval requests are not events.
_Avoid_: notification, notice

**Status**:
What a session does now: idle, thinking, calling a method, awaiting approval or stopping. It is one of these at a time.
_Avoid_: state, running, busy

**Stop**:
The user's end of a run. The run is still read to its end, but its later text is hidden and none of its remaining calls runs.
_Avoid_: abort, disconnect

**In-app agent**:
The agent a screen chats with through its session, over AG-UI or on the device. The app's user talks to it. Where nothing else is said, "the agent" is this one.
_Avoid_: assistant, chatbot

**Coding agent**:
An agent that writes the app's code, such as Claude Code or Cursor. In a debug build it calls the methods of the open screens through the bridge, as the in-app agent would.
_Avoid_: dev agent, external agent

**Bridge**:
`TandemBridge`, which a coding agent reaches a debug build through: the VM service extensions `ext.tandem.describe` and `ext.tandem.call`. A profile or release build has none.
_Avoid_: debug server, MCP server

**Front screen**:
The screen a call of the coding agent goes to when it names none: the only open `TandemScope`, or else the only one on the current route.
_Avoid_: active screen, current screen

**View**:
What the in-app agent drew with the tool `tandem_show_view`, which a `TandemView` shows: A2UI components of the catalog, bound to what the screen lists with `.sees`.
_Avoid_: surface, generated UI, widget

**Catalog**:
The seven A2UI components a view may use: Text, Column, Row, List, Card, Divider and Button, with `formatString` as the only function.
_Avoid_: components, widgets

**Chat**:
What the user sees of a session, in order: messages, notices and approval requests.
_Avoid_: timeline, history, transcript
