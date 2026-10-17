import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

const _setCustomer = 'set_customer';
const _setQuantity = 'set_quantity';
const _setDelivery = 'set_delivery';

/// How long a highlight takes to fade.
const highlightFade = Duration(seconds: 3);

/// The width of the callout's border, wide enough to catch the eye.
const _calloutWidth = 2.0;

/// The area of the customer card.
const customerArea = 'customer';

/// The area of the delivery card.
const deliveryArea = 'delivery';

/// The area of the order line of [sku].
String lineArea(String sku) => 'line $sku';

/// How often the agent changed each area of the form.
final class Highlights() extends ChangeNotifier {
  final _changes = <String, int>{};

  /// How often the agent changed [area].
  int changesOf(String area) => _changes[area] ?? 0;

  /// An [AgentCallListener]: counts a change in the area [call] touched.
  void onAgentCall(AgentCall call) {
    final area = switch ((call.tool, call.arguments['sku'])) {
      (_setCustomer, _) => customerArea,
      (_setQuantity, final String sku) => lineArea(sku),
      (_setDelivery, _) => deliveryArea,
      _ => null,
    };
    if (area != null) {
      _changes.update(area, (count) => count + 1, ifAbsent: () => 1);
      notifyListeners();
    }
  }
}

/// Gives the form below it the [Highlights] of its screen, and rebuilds the
/// areas that read them when the agent changes something.
final class const HighlightScope({
  super.key,
  required Highlights highlights,
  required super.child,
}) extends InheritedNotifier<Highlights> {
  this : super(notifier: highlights);

  /// The highlights of the closest scope above [context].
  static Highlights of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HighlightScope>();
    return switch (scope?.notifier) {
      final highlights? => highlights,
      null => throw FlutterError('No HighlightScope above $context.'),
    };
  }
}

/// An area of the form that gets the brand callout when the agent changes it,
/// and fades back over [highlightFade].
final class const Highlighted({
  super.key,
  required final String area,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final changes = HighlightScope.of(context).changesOf(area);
    return TweenAnimationBuilder(
      // Another change is another key, which starts the fade again.
      key: ValueKey(changes),
      tween: Tween<double>(begin: changes == 0 ? 0 : 1, end: 0),
      duration: highlightFade,
      curve: Curves.easeInCubic,
      builder: (context, strength, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: calloutWash.withValues(alpha: calloutWash.a * strength),
          border: .all(
            color: calloutBorder.withValues(alpha: calloutBorder.a * strength),
            width: _calloutWidth,
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
