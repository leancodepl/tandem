/// Tandem makes an existing screen agent-aware: an agent and the user work
/// on the same state on that screen.
///
/// What a screen needs: an `AgentConnection` to the agent backend, a
/// `StateHost` (the screen's own state holder), a `StateCodec` that shows
/// part of that state to the agent, and the `Tool`s the agent may call. A
/// `TandemSession` ties them together and exposes everything the UI shows as
/// a `TandemView`.
///
/// Flutter apps with bloc use `package:tandem_bloc`, which creates the
/// session for a screen. Tests use `package:tandem/testing.dart`. The AG-UI
/// wire model in `package:tandem/protocol.dart` is only for authors of
/// `AgentConnection` adapters.
library;

export 'src/protocol/agent_connection.dart' show AgentConnection;
export 'src/session/tandem_options.dart' show TandemDiagnostic, TandemOptions;
export 'src/session/tandem_session.dart' show TandemSession;
export 'src/state/state_codec.dart' show StateCodec;
export 'src/state/state_host.dart' show MemoryStateHost, StateHost;
export 'src/tools/tool.dart' show Param, Tool;
export 'src/tools/tool_args.dart' show ToolArgs, ToolArgumentError, ToolCall;
export 'src/view/agent_marks.dart' show AgentMarks;
export 'src/view/tandem_error.dart' show TandemError, TandemErrorKind;
export 'src/view/tandem_view.dart' show TandemView;
export 'src/view/timeline.dart'
    show
        AgentMessage,
        ApprovalRequest,
        ApprovalStatus,
        TimelineItem,
        ToolActivity,
        ToolActivityStatus,
        UserMessage;
