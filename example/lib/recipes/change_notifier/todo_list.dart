import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tandem/tandem.dart';

part 'todo_list.g.dart';

@TandemAgent()
class TodoList() extends ChangeNotifier with _$TodoList {
  final _changes = StreamController<Object?>.broadcast();
  final _todos = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(todos),
    .calls(add),
    if (todos.isNotEmpty) .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _changes.add(null);
  }

  /// The to-dos as the user sees them, oldest first.
  List<String> get todos => List.unmodifiable(_todos);

  /// Adds [todo] at the end of the list.
  void add(String todo) {
    _todos.add(todo);
    notifyListeners();
  }

  /// Removes every to-do.
  void clear() {
    _todos.clear();
    notifyListeners();
  }
}
