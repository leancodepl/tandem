import 'package:example/agent_chat.dart';
import 'package:example/recipes/change_notifier/todo_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';

/// A to-do list on provider's `ChangeNotifier` with the agent's chat beside
/// it.
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
        body: Row(
          children: [
            const Expanded(child: _Todos()),
            SizedBox(
              width: 360,
              child: AgentChat(
                approvalBuilder: (context, request) => _ApprovalTitle(request),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class const _Todos() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final todo in context.watch<TodoList>().todos)
        ListTile(title: Text(todo)),
    ],
  );
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
