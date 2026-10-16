import 'dart:convert';

import 'package:tandem/src/protocol/wire/messages.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';
import 'package:tandem/src/protocol/wire/wire_conventions.dart';
import 'package:tandem/src/state/state_codec.dart';

/// What the app sent in one run, with shortcuts for assertions.
///
/// A `ScriptedAgent` hands one to every turn of its script, and keeps them
/// all in `ScriptedAgent.requests`. AG-UI sends the whole history with every
/// run, so "new in this run" means "not in the previous run's request".
///
/// ```dart
/// (request) {
///   expect(request.userText, 'Add 40 HDMI cables');
///   expect(request.resultOf('search_catalog')?['status'], 'ok');
///   expect(request.reportedUserEdits, ['/order/lines/0/quantity']);
///   return [const AgentStep.say('Done.')];
/// }
/// ```
final class RunRequest {
  /// Wraps [input]. [previous] is the input of the run before, if any; what
  /// is "new in this run" is what [previous] did not contain.
  const RunRequest(this.input, {RunInput? previous}) : _previous = previous;

  /// The request exactly as the session built it.
  final RunInput input;

  final RunInput? _previous;

  /// The text of the user message new in this run, or `null` when the run
  /// carries none (an automatic follow-up, for example).
  ///
  /// When the user sent several messages during the previous run, they all
  /// go out with this one; this is the text of the last of them.
  String? get userText {
    String? text;
    for (final message in _newMessages) {
      if (message is WireUserMessage) {
        text = message.content;
      }
    }
    return text;
  }

  /// The `state` the app sent: only its own top-level keys.
  Map<String, Object?> get state => input.state;

  /// The sent [state] decoded with [codec], starting from [current].
  S stateAs<S>(StateCodec<S> codec, S current) => codec.decode(current, state);

  /// The decoded answer to the latest call of [toolName] that is new in this
  /// run, such as `{'status': 'ok', 'result': [...]}` or
  /// `{'status': 'rejected', 'approved': false}`; `null` when there is none.
  ///
  /// Throws a [FormatException] when the answer is not a JSON object, which
  /// Tandem never sends.
  Map<String, Object?>? resultOf(String toolName) {
    final toolNames = <String, String>{
      for (final message in input.messages)
        if (message is WireAssistantMessage)
          for (final call in message.toolCalls) call.id: call.name,
    };
    final answer = _newMessages
        .whereType<WireToolMessage>()
        .where((message) => toolNames[message.toolCallId] == toolName)
        .lastOrNull;
    if (answer == null) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(answer.content);
    } on FormatException {
      throw FormatException(
        'The answer to the $toolName call ${answer.toolCallId} is not JSON.',
        answer.content,
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException(
        'The answer to the $toolName call ${answer.toolCallId} is not a JSON '
        'object.',
        answer.content,
      );
    }
    return decoded;
  }

  /// The shared-state fields the user changed by hand since the previous
  /// run, as JSON Pointers into [state] such as `/order/lines/1/quantity`.
  /// Empty when the session reported none.
  ///
  /// Throws a [FormatException] when the session sent the list in a shape
  /// other than a JSON array of strings.
  List<String> get reportedUserEdits => [
    for (final entry in input.context)
      if (entry.description == WireConventions.userEditsDescription)
        ..._pointers(entry.value),
  ];

  Iterable<WireMessage> get _newMessages {
    final previousIds = {...?_previous?.messages.map((message) => message.id)};
    return input.messages.where((message) => !previousIds.contains(message.id));
  }

  static List<String> _pointers(String value) {
    Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! List<Object?> || decoded.any((item) => item is! String)) {
      throw FormatException(
        'The user edits in the run context are not a JSON array of JSON '
        'Pointers.',
        value,
      );
    }
    return decoded.cast<String>();
  }
}
