// Internal: not exported.

import 'package:tandem/src/protocol/wire/messages.dart';

/// The AG-UI history of a session: every message, in order, as the next run
/// sends it.
///
/// Messages are kept by id: adding a message whose id is already there
/// updates that message in place, so a `MESSAGES_SNAPSHOT` followed by the
/// end of a message it already contains never duplicates an id. An agent
/// text message takes its place when it starts, so a tool call made while
/// the text streams comes after it.
final class History {
  final _messages = <WireMessage>[];

  /// Text messages that started and did not end yet. They keep their place
  /// in the history but are not sent until they end or get a tool call.
  final _unfinished = <String>{};

  /// The whole history, oldest first.
  List<WireMessage> get messages => List.unmodifiable([
    for (final message in _messages)
      if (!_unfinished.contains(message.id)) message,
  ]);

  /// Replaces the whole history, for a `MESSAGES_SNAPSHOT`.
  void replace(List<WireMessage> messages) {
    _unfinished.clear();
    _messages
      ..clear()
      ..addAll(messages);
  }

  /// Adds a user message.
  void addUser(String id, String text) => _upsert(WireUserMessage(id, text));

  /// Keeps the place of the agent's text message [id], which started. It is
  /// sent once it ends ([addText]) or gets a tool call.
  void startText(String id) {
    if (_indexOf(id) == null) {
      _messages.add(WireAssistantMessage(id));
      _unfinished.add(id);
    }
  }

  /// Adds the agent's text message [id] or sets the text of the assistant
  /// message [id] that is already there, keeping its tool calls.
  void addText(String id, String text) {
    _unfinished.remove(id);
    final index = _indexOf(id);
    final existing = index == null ? null : _messages[index];
    if (index != null && existing is WireAssistantMessage) {
      _messages[index] = WireAssistantMessage(
        id,
        content: text,
        toolCalls: existing.toolCalls,
      );
    } else {
      _upsert(WireAssistantMessage(id, content: text));
    }
  }

  /// Drops the text messages that started and never ended, for a run that
  /// was stopped or failed.
  void dropUnfinished() {
    _messages.removeWhere((message) => _unfinished.contains(message.id));
    _unfinished.clear();
  }

  /// Adds [call] to the assistant message [messageId], which is created when
  /// it is not there yet. Does nothing when the call is already there.
  void addToolCall(String messageId, WireToolCall call) {
    if (containsCall(call.id)) {
      return;
    }
    _unfinished.remove(messageId);
    final index = _indexOf(messageId);
    final existing = index == null ? null : _messages[index];
    if (index != null && existing is WireAssistantMessage) {
      _messages[index] = WireAssistantMessage(
        messageId,
        content: existing.content,
        toolCalls: [...existing.toolCalls, call],
      );
    } else {
      _upsert(WireAssistantMessage(messageId, toolCalls: [call]));
    }
  }

  /// Adds a tool message: the answer to [toolCallId].
  void addToolMessage(
    String id, {
    required String toolCallId,
    required String content,
  }) => _upsert(WireToolMessage(id, toolCallId: toolCallId, content: content));

  /// Whether an assistant message contains the tool call [toolCallId].
  bool containsCall(String toolCallId) => _messages.any(
    (message) =>
        message is WireAssistantMessage &&
        message.toolCalls.any((call) => call.id == toolCallId),
  );

  void _upsert(WireMessage message) {
    final index = _indexOf(message.id);
    if (index == null) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
  }

  int? _indexOf(String id) {
    final index = _messages.indexWhere((message) => message.id == id);
    return index == -1 ? null : index;
  }
}
