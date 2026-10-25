/// Who called a listed method, as `AgentCall` and `ApprovalRequest` say.
enum Caller() {
  /// The agent the screen chats with, in its run.
  inAppAgent,

  /// A coding agent, through `TandemBridge`.
  codingAgent,

  /// The user, with a press on a button of a view the in-app agent drew in a
  /// `TandemView`.
  view,
}
