/// Who called a listed method, as `AgentCall` and `ApprovalRequest` say.
enum Caller() {
  /// The agent the screen chats with, in its run.
  inAppAgent,

  /// A coding agent, through `TandemBridge`.
  codingAgent,
}
