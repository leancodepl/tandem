/// Who called a listed method.
enum Caller() {
  /// The agent the screen chats with, in its run.
  inAppAgent,

  /// A coding agent, through `TandemBridge`.
  codingAgent,
}
