/// Makes an existing Flutter screen agent-aware over AG-UI.
///
/// A state class with `@TandemAgent()` lists what the agent sees with
/// `.sees` and which of its methods it may call with `.calls` and
/// `.callsWithApproval`. `tandem_generator` writes the code behind the list.
/// `TandemScope` opens a `TandemSession` of that class with an AG-UI agent,
/// and the app's own chat or buttons drive it through
/// `TandemSessionScope.of`. In a debug build, `TandemBridge` lets a coding
/// agent drive the same screens.
library;

export 'src/agent_list.dart' show AgentCapability;
export 'src/agent_schema.dart'
    show AgentSchema, AgentSurface, AgentTool, AgentView;
export 'src/chat/chat_item.dart'
    show
        AgentMessage,
        ApprovalRequest,
        ApprovalStatus,
        ChatItem,
        ChatNotice,
        ChatNoticeKind,
        UserMessage;
export 'src/debug/tandem_bridge.dart' show TandemBridge;
export 'src/errors.dart'
    show
        AgentHttpException,
        AgentRunException,
        ApprovalNotPending,
        RunErrorCode,
        ToolCallRefused;
export 'src/protocol/agent_connection.dart'
    show AgentConnection, HttpAgentConnection;
export 'src/protocol/on_device_agent.dart'
    show OnDeviceAgent, OnDeviceAvailability, OnDeviceErrorCode;
export 'src/session/approvals.dart' show ApprovalCallback, TandemApprovals;
export 'src/session/session_scope.dart' show TandemSessionScope;
export 'src/session/session_status.dart'
    show AwaitingApproval, Calling, Idle, SessionStatus, Stopping, Thinking;
export 'src/session/tandem_event.dart'
    show AgentCall, ConnectionLost, RunFailed, RunStopped, TandemEvent;
export 'src/session/tandem_scope.dart' show TandemScope;
export 'src/session/tandem_session.dart' show TandemSession;
export 'src/tandem_agent.dart' show TandemAgent;
export 'src/tool_args.dart' show ToolArgs;
