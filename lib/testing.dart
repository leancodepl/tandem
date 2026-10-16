/// Test support for agent-aware screens: a `ScriptedAgent` that plays a
/// script instead of calling a real agent backend, with no network and no
/// API key.
///
/// An AG-UI agent works in runs: the app sends a request (the user's
/// message, the whole history, the shared state and the tools it offers),
/// and the agent streams events back. A `ScriptedAgent` answers each run
/// with the next `AgentTurn` of its script. A turn gets the `RunRequest` the
/// app sent, so the test can check it, and returns the `AgentStep`s the agent
/// takes: say something, call a tool of the app, run one of its own tools,
/// change the shared state, or fail.
///
/// By default the agent behaves like ag-ui-adk (Google ADK's AG-UI
/// middleware) and rejects requests that break the AG-UI rules, so a test
/// exercises the same events and the same mistakes as production.
///
/// ```dart
/// testWidgets('fills the order from the e-mail', (tester) async {
///   final agent = ScriptedAgent([
///     (request) {
///       expect(request.userText, 'Two HDMI cables');
///       return const [AgentStep.callTool('search_catalog', {'query': 'HDMI'})];
///     },
///     (request) {
///       expect(request.resultOf('search_catalog')?['status'], 'ok');
///       return const [AgentStep.say('Added two HDMI cables.')];
///     },
///   ]);
///   // Provide `agent` as the screen's AgentConnection, then type and send.
///   await tester.pumpAndSettle();
///   expect(agent.isExhausted, isTrue);
/// });
/// ```
library;

export 'src/testing/run_request.dart' show RunRequest;
export 'src/testing/scripted_agent.dart'
    show AgentStep, AgentTurn, ScriptedAgent;
