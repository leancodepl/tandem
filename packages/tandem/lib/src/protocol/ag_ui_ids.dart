import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// The id of a tool call in an AG-UI thread. A backend picks the id of each
/// call it makes, and may repeat it in a later run of the thread.
extension type const ToolCallId._(String value) {
  /// The id a backend gave its call.
  @internal
  const new wire(String value) : this._(value);

  /// A new id, for a call that comes from outside a run, such as a coding
  /// agent's.
  @internal
  new local() : this._(const Uuid().v4());
}

/// The id of a message in an AG-UI thread. ag-ui-adk marks every message id
/// it has seen as processed and skips a later message under the same id.
extension type const MessageId._(String value) {
  /// The id a backend gave its message.
  const new wire(String value) : this._(value);

  /// A new id, for a message Tandem adds to the thread, which no other
  /// message of the thread has.
  new local() : this._(const Uuid().v4());
}
