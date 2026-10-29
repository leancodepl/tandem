// Written with classic constructors, as many design systems still are.
// ignore_for_file: use_primary_constructors, unnecessary_type_name_in_constructor

import 'package:flutter/widgets.dart';
import 'package:kit_ds/src/kit_style.dart';

/// The line the kit draws under a note, solid or dashed. Only the kit picks
/// which.
final class KitRule {
  const KitRule._(this.dashed);

  final bool dashed;
}

/// A run of text in one of the kit's styles.
class KitText extends StatelessWidget {
  const KitText({
    super.key,
    required this.style,
    required this.value,
    this.align,
  });

  final KitStyle style;
  final String value;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) =>
      Text(value, style: style.text, textAlign: align);
}

/// A remark set apart from the text around it.
class KitNote extends StatelessWidget {
  const KitNote(this.body, {super.key, this.slant = .italic, this.rule});

  final String body;
  final FontStyle slant;
  final KitRule? rule;

  @override
  Widget build(BuildContext context) =>
      Text(body, style: TextStyle(fontStyle: slant));
}

/// Items one below another, the first [limit] of them when it is set.
class KitStack extends StatelessWidget {
  const KitStack({
    super.key,
    this.limit,
    this.divided = false,
    required this.children,
  });

  final int? limit;
  final bool divided;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      for (final (index, child)
          in children.take(limit ?? children.length).indexed) ...[
        if (divided && index > 0)
          const ColoredBox(
            color: Color(0x1F000000),
            child: SizedBox(height: 1),
          ),
        child,
      ],
    ],
  );
}

/// A label to tap.
class KitButton extends StatelessWidget {
  const KitButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Text(
      label,
      style: TextStyle(
        color: onPressed == null
            ? const Color(0xFF9E9E9E)
            : const Color(0xFF000000),
      ),
    ),
  );
}

/// A word or two on a colored fill, such as "In stock".
class KitChip extends StatelessWidget {
  const KitChip({super.key, required this.fill, required this.text});

  final Color fill;
  final String text;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: fill,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(text),
    ),
  );
}
