/// Marks a class for `tandem_generator`, which writes its `_$ClassName` mixin
/// from its `List<AgentCapability> get agentCapabilities`. A class without this
/// annotation gets no mixin, even with the getter.
final class const TandemAgent() {
  /// Used as `@TandemAgent()` on the class.
  this;
}
