/// To run without a model, in a test or to try a screen: `ScriptedAgent`
/// plays a script in place of the agent, and `AgentListing` shows what a
/// class gives the agent.
library;

export 'src/agent_list.dart' show AgentListing;
export 'src/testing/scripted_agent.dart'
    show AgentStep, AgentTurn, ScriptedAgent, ScriptedErrorCode;
