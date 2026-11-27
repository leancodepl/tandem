import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

part 'quick_start.g.dart';

@TandemAgent()
class ShoppingCubit() extends Cubit<List<String>> with _$ShoppingCubit {
  this : super(const []);

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .calls(add),
    .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// What is on the shopping list now.
  List<String> get items => state;

  /// Adds [item] to the list.
  void add(String item) => emit([...state, item]);

  /// Removes every item from the list.
  void clear() => emit(const []);
}

final class const ShoppingScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ShoppingCubit(),
    child: TandemScope(
      surface: (context) => context.read<ShoppingCubit>(),
      approvals: const .callback(confirmClear),
      child: Scaffold(
        body: BlocBuilder<ShoppingCubit, List<String>>(
          builder: (context, items) => SingleChildScrollView(
            child: Column(
              children: [
                for (final item in items) ListTile(title: Text(item)),
                const TandemView(catalog: ShoppingCatalog()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> confirmClear(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final approved =
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear the list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      ) ??
      false;
  try {
    if (approved) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The list changed, or the screen closed, while the dialog showed.
  }
}

/// Suggested items, one below another.
final class const Suggestions({super.key, required final List<Widget> children})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: children);
}

/// An item to add to the list, with a button that adds it.
final class const Suggestion({
  super.key,
  required final String item,
  required final VoidCallback onAdd,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(item),
    trailing: TextButton(onPressed: onAdd, child: const Text('Add')),
  );
}

/// Suggest items the list does not have yet. Draw one Suggestions with a
/// Suggestion for each item. Its onAdd calls add with that item.
///
/// ```json
/// [
///   {"id": "root", "component": "Suggestions", "children": ["milk"]},
///   {"id": "milk", "component": "Suggestion", "item": "milk",
///    "onAdd": {"action": {"event": {"name": "add", "context": {"item": "milk"}}}}}
/// ]
/// ```
@TandemCatalog([Suggestions, Suggestion])
final class const ShoppingCatalog() with _$ShoppingCatalog;

void main() {
  TandemBridge.enable();
  runApp(const MaterialApp(home: ShoppingScreen()));
}
