/// For tests: `ScriptedAgent` plays a script instead of a model, and
/// `AgentListing` shows what a class gives the agent and calls its methods
/// as the agent would. Import it in tests, not in the app.
library;

export 'src/agent_list.dart' show AgentListing;
export 'src/testing/scripted_agent.dart'
    show AgentStep, AgentTurn, ScriptedAgent;
