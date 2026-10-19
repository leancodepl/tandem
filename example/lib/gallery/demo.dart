import 'package:example/desk/data/emails.dart';
import 'package:example/desk/ui/order_desk_screen.dart';
import 'package:example/gallery/demo_agents.dart';
import 'package:example/recipes/approval_dialog/reply_screen.dart';
import 'package:example/recipes/change_notifier/todo_screen.dart';
import 'package:example/recipes/fill_from_email/contact_screen.dart';
import 'package:example/recipes/riverpod/cart_screen.dart';
import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tandem/tandem.dart';

enum Demo(
  final String title,
  final String summary,
  final String instruction,
  final String stateLibrary,
  final IconData icon,
) {
  orderDesk(
    'Order desk',
    'Turn an e-mail into an order. Edit quantities before placing it.',
    'Fill the draft, edit a quantity, then ask to place the order.',
    'bloc',
    Icons.receipt_long_outlined,
  ),
  shoppingList(
    'Shopping list',
    'Let the agent add items. Decide whether it may empty the list.',
    'Run the prompt, then remove an item while approval is pending.',
    'bloc',
    Icons.checklist_outlined,
  ),
  contact(
    'Contact form',
    'Fill a regular form from an e-mail, without a chat widget.',
    'Fill the form from the sample e-mail, then edit any field.',
    'bloc',
    Icons.contact_mail_outlined,
  ),
  reply(
    'Reply approval',
    'Let the agent answer a customer. Confirm sending in a dialog.',
    'Ask for an answer, then send or cancel it in the dialog. '
        'Sending is simulated.',
    'bloc',
    Icons.mark_email_read_outlined,
  ),
  cart(
    'Shopping cart',
    'Use the same Riverpod state for manual edits and agent actions.',
    'Remove an item before checkout approval, then ask again. '
        'Checkout is simulated.',
    'Riverpod',
    Icons.shopping_bag_outlined,
  ),
  todos(
    'To-do list',
    'Connect a ChangeNotifier and keep approvals tied to its state.',
    'Add a task while approval is pending, then ask to clear the list again.',
    'provider',
    Icons.task_alt,
  );

  bool get canUseBackend => this == orderDesk;

  AgentConnection scriptedAgent() => switch (this) {
    orderDesk => orderDeskAgent(),
    shoppingList => shoppingListAgent(),
    contact => contactAgent(),
    reply => replyAgent(),
    cart => cartAgent(),
    todos => todoAgent(),
  };

  Widget screen(AgentConnection connection) => switch (this) {
    orderDesk => OrderDeskScreen(connection: connection),
    shoppingList => ShoppingListScreen(connection: connection),
    contact => ContactScreen(
      connection: connection,
      initialEmail: contactEmail,
    ),
    reply => ReplyScreen(connection: connection),
    cart => ProviderScope(child: CartScreen(connection: connection)),
    todos => TodoScreen(connection: connection),
  };
}
