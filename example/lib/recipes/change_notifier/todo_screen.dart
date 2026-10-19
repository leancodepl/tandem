import 'package:example/agent_chat.dart';
import 'package:example/agent_workspace.dart';
import 'package:example/item_input.dart';
import 'package:example/recipes/change_notifier/todo_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';

/// A to-do list on provider's `ChangeNotifier` with the agent's chat.
final class const TodoScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => TodoList(),
    child: TandemScope.connected(
      surface: (context) => context.read<TodoList>(),
      connection: connection,
      approvals: const .fromState(),
      child: Scaffold(
        body: AgentWorkspace(
          title: 'Release tasks',
          chat: AgentChat(
            suggestion: 'Add two release tasks, then clear the list.',
            approvalBuilder: (context, request) => _ApprovalTitle(request),
          ),
          child: const _Todos(),
        ),
      ),
    ),
  );
}

final class const _Todos() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final list = context.watch<TodoList>();

    return Column(
      children: [
        Expanded(
          child: switch (list.todos) {
            [] => const Center(child: Text('No tasks yet.')),
            final todos => ListView(
              padding: const .symmetric(vertical: 8),
              children: [
                for (final todo in todos)
                  ListTile(
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(todo),
                  ),
              ],
            ),
          },
        ),
        ItemInput(label: 'Add a task', onAdd: list.add),
      ],
    );
  }
}

// In an app, these texts come from its localizations, such as the
// AppLocalizations class that `flutter gen-l10n` writes.
final class const _ApprovalTitle(final ApprovalRequest request)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(switch ((
    Localizations.localeOf(context).languageCode,
    request.tool,
  )) {
    ('pl', 'clear') => 'Usunąć wszystkie zadania?',
    (_, 'clear') => 'Remove every to-do?',
    _ => request.description,
  });
}
