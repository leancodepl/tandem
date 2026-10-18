import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:tandem/testing.dart';

// Plays these turns whatever the user writes. A run past the script fails.
final _agent = ScriptedAgent([
  (_) => const [
    AgentStep.callTool('add', {'item': 'Milk'}),
    AgentStep.callTool('add', {'item': 'Bread'}),
  ],
  (_) => const [
    AgentStep.say('Added milk and bread. Shall I empty the list?'),
    AgentStep.callTool('clear'),
  ],
  (_) => const [AgentStep.say('Done.')],
]);

void main() =>
    runApp(MaterialApp(home: ShoppingListScreen(connection: _agent)));
