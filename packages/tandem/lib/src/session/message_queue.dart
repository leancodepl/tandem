import 'package:tandem/src/chat/chat_item.dart';

/// The messages of the user and the app for the next run, which sends them
/// as one user message: ag-ui-adk passes the model only the last new user
/// message of a run.
final class MessageQueue() {
  /// Oldest first.
  final _messages = <UserMessage>[];

  /// How many of the oldest messages never reached the agent although a run
  /// took them. They go with the next run but start none.
  var _carried = 0;

  /// Whether the app's messages wait for the user's next one, because the
  /// user stopped the run they waited for.
  var _appMessagesHeld = false;

  void add(UserMessage message) => _messages.add(message);

  /// Whether the user wrote a message that no run took yet.
  bool get userWrote => _waiting.any((message) => !message.fromApp);

  /// Whether a message of the app waits to start a run.
  bool get appMessageWaits => _waiting.isNotEmpty && !_appMessagesHeld;

  /// The app's messages wait for the user's next one.
  void holdAppMessages() {
    if (_waiting.isNotEmpty) {
      _appMessagesHeld = true;
    }
  }

  /// Every message waits for the next run without starting one, as after a
  /// run that took them but never reached the agent.
  void carry() {
    _carried = _messages.length;
    _appMessagesHeld = false;
  }

  /// The texts for the run that starts now, joined by a blank line, or null
  /// when no message waits.
  String? get text => _messages.isEmpty
      ? null
      : _messages.map((message) => message.text).join('\n\n');

  /// The run that took [text] went out with it.
  void sent() {
    _messages.clear();
    _carried = 0;
    _appMessagesHeld = false;
  }

  Iterable<UserMessage> get _waiting => _messages.skip(_carried);
}
