import 'package:example/agent_chat.dart';
import 'package:example/agent_workspace.dart';
import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

/// The agent of [DrawnListScreen] on a script that plays these turns
/// whatever the user writes. A run past the script fails.
ScriptedAgent drawnListAgent() => ScriptedAgent([
  (_) => const [
    AgentStep.callTool('add', {'item': 'Milk'}),
    AgentStep.callTool('add', {'item': 'Bread'}),
    AgentStep.callTool('show_view', {'messages': _view}),
  ],
  (_) => const [
    AgentStep.say('Here is your list. Remove an item, or empty the list.'),
  ],
  (_) => const [AgentStep.say('I only draw the list in this demo.')],
  (_) => const [AgentStep.say('I only draw the list in this demo.')],
]);

const _view = [
  {
    'version': 'v0.9.1',
    'createSurface': {
      'surfaceId': 'main',
      'catalogId': 'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json',
    },
  },
  {
    'version': 'v0.9.1',
    'updateComponents': {
      'surfaceId': 'main',
      'components': [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['title', 'items', 'divider', 'clear'],
        },
        {
          'id': 'title',
          'component': 'Text',
          'text': 'Your shopping list',
          'variant': 'h2',
        },
        {
          'id': 'items',
          'component': 'List',
          'children': {'componentId': 'item', 'path': '/items'},
        },
        {
          'id': 'item',
          'component': 'Row',
          'children': ['name', 'remove'],
        },
        {
          'id': 'name',
          'component': 'Text',
          'text': {'path': '.'},
        },
        {
          'id': 'remove',
          'component': 'Button',
          'child': 'remove_label',
          'variant': 'borderless',
          'action': {
            'event': {
              'name': 'remove',
              'context': {
                'item': {'path': '.'},
              },
            },
          },
        },
        {'id': 'remove_label', 'component': 'Text', 'text': 'Remove'},
        {'id': 'divider', 'component': 'Divider'},
        {
          'id': 'clear',
          'component': 'Button',
          'child': 'clear_label',
          'variant': 'primary',
          'action': {
            'event': {'name': 'clear'},
          },
        },
        {'id': 'clear_label', 'component': 'Text', 'text': 'Empty the list'},
      ],
    },
  },
];

// fvm flutter run -t lib/shopping_list/drawn_list.dart
void main() {
  TandemBridge.enable();
  runApp(MaterialApp(home: DrawnListScreen(connection: drawnListAgent())));
}

/// The shopping list as a view the agent draws in a `TandemView`.
final class const DrawnListScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ShoppingListCubit(),
    child: TandemScope.connected(
      surface: (context) => context.read<ShoppingListCubit>(),
      connection: connection,
      approvals: const .fromState(),
      child: const Scaffold(
        body: AgentWorkspace(
          title: 'Drawn by the agent',
          chat: AgentChat(suggestion: 'Show my shopping list.'),
          child: Padding(padding: .all(12), child: TandemView()),
        ),
      ),
    ),
  );
}
