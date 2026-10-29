import 'dart:convert';

import 'package:tandem/src/protocol/ag_ui.dart';

/// One thing that happened in the app outside the chat, as the agent reads
/// it.
extension type const AppNote._(JsonObject json) {
  /// What the app wrote with `session.note`.
  factory text(String text) => ._({'note': text});
}

/// The latest notes of the app, which every run gives the agent in one
/// `context` entry, so a backend that keeps no `context` of earlier runs
/// still has them.
final class AppNotes() {
  /// How many notes the entry keeps, the oldest dropped first.
  static const _kept = 5;

  /// Oldest first.
  final _notes = <AppNote>[];

  /// How many of the newest notes no finished run offered yet.
  var _unsent = 0;

  /// How many new notes the open run offered.
  var _offered = 0;

  void add(AppNote note) {
    _notes.add(note);
    _unsent++;
    if (_notes.length <= _kept) {
      return;
    }
    _notes.removeAt(0);
    // Every note was new, so the one dropped was new too, and offered if any
    // was: the offered notes are older than the rest.
    if (_unsent > _notes.length) {
      _unsent--;
      if (_offered > 0) {
        _offered--;
      }
    }
  }

  /// The `context` entry for the run that starts now, or null before the
  /// first note. Its new notes stay new until [read].
  JsonObject? offer() {
    if (_notes.isEmpty) {
      return null;
    }
    final firstNew = _notes.length - _unsent;
    final value = {
      'new': [for (final note in _notes.skip(firstNew)) note.json],
      'earlier': [for (final note in _notes.take(firstNew)) note.json],
    }..removeWhere((_, notes) => notes.isEmpty);
    _offered = _unsent;
    return {
      AgUiFields.description:
          'app_notes: What happened in the app outside this chat, oldest '
          'first: "new" since your last turn, "earlier" before it.',
      AgUiFields.value: jsonEncode(value),
    };
  }

  /// The run that took the last entry finished, so the agent read its new
  /// notes. A run that failed or broke off leaves them new.
  void read() {
    _unsent -= _offered;
    _offered = 0;
  }
}
