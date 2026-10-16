/// Makes an existing Flutter screen agent-aware over AG-UI. The agent sees
/// what the screen shares and acts through listed methods.
library;

export 'src/agent_list.dart' show AgentCapability, AgentListing;
export 'src/agent_schema.dart'
    show AgentSchema, AgentSurface, AgentTool, AgentView, ToolArgs;
export 'src/errors.dart' show AgentHttpException, ToolCallRefused;
