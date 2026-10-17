import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/tool_call.dart';

/// What the session keeps of its open run.
final class Run(final AgentListing listing) {
  /// The agent's messages as the chat shows them, by message id.
  final texts = <String, AgentMessage>{};
  final calls = <String, ToolCall>{};
  bool stopped = false;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  List<Map<String, Object?>> get assistantTexts => [
    for (final MapEntry(key: id, value: message) in texts.entries)
      assistantText(id, message.text),
  ];
}
