import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/material.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/drawn_view.dart';

/// The current bounded tree of [view], drawn with Tandem's catalog.
final class const DrawnSurface(
  final DrawnView view,
  final ComponentNode<ComponentApi> root, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Node(view, root);
}

/// One component, drawn again whenever its resolved properties change.
final class const _Node(
  final DrawnView view,
  final ComponentNode<ComponentApi> node,
) extends StatefulWidget {
  @override
  State<_Node> createState() => _NodeState();
}

final class _NodeState() extends State<_Node> {
  late NodeProps _props;
  late void Function() _unsubscribe;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_Node oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.node, oldWidget.node)) {
      _unsubscribe();
      _listen();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final nodes = switch (_props[A2uiFields.children]) {
      final List<Object?> nodes =>
        nodes.whereType<ComponentNode<ComponentApi>>(),
      _ => const <ComponentNode<ComponentApi>>[],
    };
    final children = [for (final node in nodes) _Node(view, node)];
    final child = switch (_props[A2uiFields.child]) {
      final ComponentNode<ComponentApi> node => _Node(view, node),
      _ => const SizedBox.shrink(),
    };
    return switch (CatalogComponent.named(widget.node.type)) {
      .text => _Text(
        _props[A2uiFields.text],
        TextVariant.named(_props[A2uiFields.variant]),
      ),
      .column || .list => Column(
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: children,
      ),
      // The texts share the width, so the columns of a list line up, and a
      // button keeps the width of its label.
      .row => Row(
        spacing: 12,
        children: [
          for (final node in nodes)
            if (node.type == CatalogComponent.button.wireName)
              _Node(view, node)
            else
              Expanded(child: _Node(view, node)),
        ],
      ),
      .card => Card(
        child: Padding(padding: const .all(12), child: child),
      ),
      .divider => const Divider(),
      .button => _Button(
        view,
        widget.node,
        ButtonVariant.named(_props[A2uiFields.variant]),
        child: child,
      ),
      // The check refuses a component outside the catalog.
      null => const SizedBox.shrink(),
    };
  }

  void _listen() {
    _props = widget.node.props.peek();
    _unsubscribe = widget.node.props.subscribe((props) {
      if (!identical(props, _props)) {
        setState(() => _props = props);
      }
    });
  }
}

final class const _Text(final Object? _binding, final TextVariant _variant)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final styles = TextTheme.of(context);
    return Text(
      switch (_binding) {
        ResolvedBinding(:final value?) => '$value',
        _ => '',
      },
      // A body text keeps the style around it, such as a button's.
      style: switch (_variant) {
        .h1 => styles.headlineSmall,
        .h2 => styles.titleLarge,
        .h3 => styles.titleMedium,
        .h4 => styles.titleSmall,
        .h5 => styles.labelLarge,
        .caption => styles.bodySmall,
        .body => null,
      },
    );
  }
}

/// A button, enabled while [view] lets [node] be pressed: it changes with
/// the view's presses and the session's status.
final class const _Button(
  final DrawnView view,
  final ComponentNode<ComponentApi> node,
  final ButtonVariant _variant, {
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([view, view.session]),
    builder: (context, _) {
      final onPressed = view.canPress(node)
          ? () => unawaited(view.press(node))
          : null;
      return switch (_variant) {
        .primary => FilledButton(onPressed: onPressed, child: child),
        .borderless => TextButton(onPressed: onPressed, child: child),
        .outlined => OutlinedButton(onPressed: onPressed, child: child),
      };
    },
  );
}
