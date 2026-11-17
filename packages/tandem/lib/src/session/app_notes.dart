import 'dart:convert';

import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// One thing that happened in the app outside the chat, as the agent reads
/// it.
extension type const AppNote._(JsonObject json) {
  /// What the app wrote with `session.note`.
  factory text(String text) => ._({'note': text});

  /// An action of a view the agent drew, by the user, that called [tool]
  /// with [arguments] and got [answer].
  factory action(String tool, Object? arguments, ToolAnswer answer) =>
      ._({'pressed': tool, 'arguments': arguments, ...answer.json});
}

/// The latest notes of the app, which every run gives the agent in one
/// `context` entry, so a backend that keeps no `context` of earlier runs
/// still has them.
final class AppNotes() {
  /// How many notes the entry keeps, the oldest dropped first.
  static const _kept = 5;

  final _notes = <({int number, AppNote note})>[];
  var _latest = 0;

  /// The last note offered to a run, and the last one a finished run read.
  var _offeredThrough = 0;
  var _readThrough = 0;

  void add(AppNote note) {
    _notes.add((number: ++_latest, note: note));
    if (_notes.length > _kept) _notes.removeAt(0);
  }

  /// The `context` entry for the run that starts now, or null before the
  /// first note. Its new notes stay new until [read].
  JsonObject? offer() {
    if (_notes.isEmpty) {
      return null;
    }
    final fresh = [
      for (final entry in _notes)
        if (entry.number > _readThrough) entry.note.json,
    ];
    final earlier = [
      for (final entry in _notes)
        if (entry.number <= _readThrough) entry.note.json,
    ];
    _offeredThrough = _latest;
    return {
      AgUiFields.description:
          'app_notes: What happened in the app outside this chat, oldest '
          'first: "new" since your last turn, "earlier" before it.',
      AgUiFields.value: jsonEncode({
        if (fresh.isNotEmpty) 'new': fresh,
        if (earlier.isNotEmpty) 'earlier': earlier,
      }),
    };
  }

  /// The run that took the last entry finished, so the agent read its new
  /// notes. A run that failed or broke off leaves them new.
  void read() => _readThrough = _offeredThrough;
}
