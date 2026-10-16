/// Makes an existing Flutter screen agent-aware over AG-UI. The agent sees
/// what the screen shares and acts through listed methods.
library;

export 'src/agent_list.dart' show AgentCapability, AgentListing;
export 'src/agent_schema.dart'
    show AgentSchema, AgentSurface, AgentTool, AgentView, ToolArgs;
export 'src/chat/chat_item.dart'
    show
        AgentMessage,
        ApprovalRequest,
        ApprovalStatus,
        ChatItem,
        ChatNotice,
        ChatNoticeKind,
        UserMessage;
export 'src/chat/tandem_chat.dart' show ApprovalBuilder, TandemChat;
export 'src/errors.dart' show AgentHttpException, ToolCallRefused;
export 'src/protocol/agent_connection.dart'
    show AgentConnection, HttpAgentConnection;
export 'src/session.dart' show AgentCallListener, TandemSession;
export 'src/session_scope.dart' show TandemSessionScope;
export 'src/testing/scripted_agent.dart'
    show AgentStep, AgentTurn, ScriptedAgent;
