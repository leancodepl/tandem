import 'package:flutter/widgets.dart' hide Page;
import 'package:greenhouse_app/contracts.dart';

/// A plant by its label and the light it wants. A tap picks it.
final class const PlantRow({
  super.key,
  required final VoidCallback onPick,
  required final PlantDTO plant,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPick,
    child: Row(children: [Text(plant.label), Text(plant.light.name)]),
  );
}

/// How a meter draws its count.
enum Gauge() {
  dots,
  bar,
  digits,
}

/// How many pots the user wants, drawn as [gauge] says.
final class const PotMeter({
  super.key,
  required final int pots,
  final Gauge gauge = .dots,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(switch (gauge) {
    .dots => 'o' * pots,
    .bar => '[${'=' * pots}]',
    .digits => '$pots',
  });
}

/// A message about what the user just did, with a button that undoes it
/// while the screen can.
final class const UndoBar({
  super.key,
  required final String message,
  final VoidCallback? onUndo,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(message),
      if (onUndo != null)
        GestureDetector(onTap: onUndo, child: const Text('Undo')),
    ],
  );
}

/// A field for the number of pots.
final class const PotsField({
  super.key,
  required final int pots,
  final ValueChanged<int>? onPots,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: switch (onPots) {
      final change? => () => change(pots + 1),
      null => null,
    },
    child: Text('$pots pots'),
  );
}

/// The plants side by side, by label.
final class const SideBySide({super.key, required final List<PlantDTO> plants})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text([for (final plant in plants) plant.label].join(' | '));
}

/// Which page of labels this is, on a page whose hidden labels are null.
final class const PageNumber({super.key, required final Page<String?> page})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('Page ${page.number}');
}
