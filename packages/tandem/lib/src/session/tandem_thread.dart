import 'package:meta/meta.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session/ag_ui_thread.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// A conversation of a screen with the agent, which the app can hold and
/// give to the next session of the screen, such as when the screen opens
/// again: its chat, and the AG-UI thread with its messages and the agent's
/// state. It lives in memory.
///
/// One session goes on with it at a time: the newest. Starting over clears
/// the local history and agent state. The chat stays. A thread with an ID
/// from the app keeps that ID. After `session.startOver()` or a screen change
/// between sessions, it also keeps completed calls whose answers are still
/// waiting to go out.
final class TandemThread({
  /// The AG-UI thread id of a conversation that the backend keeps, such as
  /// its own conversation id. Every run sends it, and Tandem never changes
  /// it. Without it, Tandem picks one.
  String? id,
}) {
  /// Oldest first.
  @internal
  final items = <ChatItem>[];

  @internal
  final agUiThread = AgUiThread(id: id);

  TandemSession? _session;

  /// The id of its AG-UI thread, which every run sends.
  String get id => agUiThread.id;

  /// Lets [session] go on with the thread. A session that went on with it
  /// lets it go as if it closed, such as one of a screen that animates out.
  @internal
  void claim(TandemSession session) {
    final previous = _session;
    _session = session;
    previous?.letGoOfThread();
  }

  @internal
  void release(TandemSession session) {
    if (identical(session, _session)) {
      _session = null;
    }
  }
}
