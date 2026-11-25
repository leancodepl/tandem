import 'package:uuid/uuid.dart';

extension type const AgUiThreadId(String value);

extension type const AgUiRunId(String value);

extension type const ToolName(String value);

/// The id of a tool call in an AG-UI thread. Tandem runs the call and names
/// its result with this id. Tandem's own `ToolCallId` has no public
/// constructor.
extension type const ToolCallId._(String value) {
  /// The id a thread already has for a call.
  const new wire(String value) : this._(value);

  /// A new id, for a call the backend proposes.
  new unique() : this._(const Uuid().v4());
}

extension type const MessageId._(String value) {
  /// A new id, for a message the backend writes.
  new unique() : this._(const Uuid().v4());
}
