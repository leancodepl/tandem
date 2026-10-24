import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/material.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/drawn_view.dart';

/// [surface] of [view] drawn with the widgets of Tandem's catalog.
final class const DrawnSurface(
  final DrawnView view,
  final SurfaceModel<ComponentApi> surface, {
  super.key,
}) extends StatefulWidget {
  @override
  State<DrawnSurface> createState() => _DrawnSurfaceState();
}

final class _DrawnSurfaceState() extends State<DrawnSurface> {
  late NodeResolver<ComponentApi> _resolver;
  void Function()? _unsubscribe;
  ComponentNode<ComponentApi>? _root;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(DrawnSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.surface, widget.surface)) {
      _release();
      _resolve();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_root) {
    final root? => _ViewScope(widget.view, child: _Node(root)),
    null => const SizedBox.shrink(),
  };

  void _resolve() {
    _resolver = NodeResolver(widget.surface);
    _unsubscribe = _resolver.rootNode.subscribe(
      (root) => mounted ? setState(() => _root = root) : _root = root,
    );
  }

  void _release() {
    _unsubscribe?.call();
    _resolver.dispose();
  }
}

/// One component, drawn again whenever its resolved properties change.
final class const _Node(final ComponentNode<ComponentApi> node)
    extends StatefulWidget {
  @override
  State<_Node> createState() => _NodeState();
}

final class _NodeState() extends State<_Node> {
  late NodeProps _props;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_Node oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.node, widget.node)) {
      _unsubscribe?.call();
      _listen();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      switch (CatalogComponent.named(widget.node.type)) {
        .text => _Text(
          _textOf(_props[A2uiFields.text]),
          variant: _props[A2uiFields.variant],
        ),
        .column || .list => Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: _nodes(_props[A2uiFields.children]),
        ),
        .row => Row(
          spacing: 12,
          children: [
            for (final node in _nodes(_props[A2uiFields.children]))
              Expanded(child: node),
          ],
        ),
        .card => Card(
          child: Padding(
            padding: const .all(12),
            child: _nodeOf(_props[A2uiFields.child]),
          ),
        ),
        .divider => const Divider(),
        .button => _Button(
          variant: _props[A2uiFields.variant],
          onPressed: _onPressed(_ViewScope.of(context)),
          child: _nodeOf(_props[A2uiFields.child]),
        ),
        // The check refuses components outside the catalog.
        null => const SizedBox.shrink(),
      };

  VoidCallback? _onPressed(DrawnView view) {
    final node = widget.node;
    final tool = _toolOf(node);
    if (tool == null || !view.canPress(node.componentId, tool)) {
      return null;
    }
    return switch (_props[A2uiFields.action]) {
      final Future<void> Function() press => () => unawaited(press()),
      _ => null,
    };
  }

  void _listen() {
    _props = widget.node.props.peek();
    _unsubscribe = widget.node.props.subscribe((props) {
      if (mounted && !identical(props, _props)) {
        setState(() => _props = props);
      }
    });
  }
}

/// The [DrawnView] of the buttons below it.
final class const _ViewScope(final DrawnView view, {required super.child})
    extends InheritedWidget {
  static DrawnView of(BuildContext context) =>
      switch (context.dependOnInheritedWidgetOfExactType<_ViewScope>()) {
        final scope? => scope.view,
        null => throw FlutterError('A drawn component outside its view.'),
      };

  @override
  bool updateShouldNotify(_ViewScope oldWidget) =>
      !identical(view, oldWidget.view);
}

/// The method the button [node] calls, as the agent wrote it.
String? _toolOf(ComponentNode<ComponentApi> node) =>
    switch (node.context?.componentModel.properties[A2uiFields.action]) {
      {A2uiFields.event: {A2uiFields.name: final String name}} => name,
      _ => null,
    };

List<Widget> _nodes(Object? children) => [
  if (children case final List<Object?> nodes)
    for (final node in nodes.whereType<ComponentNode<ComponentApi>>())
      _Node(node),
];

Widget _nodeOf(Object? child) => switch (child) {
  final ComponentNode<ComponentApi> node => _Node(node),
  _ => const SizedBox.shrink(),
};

String _textOf(Object? binding) => switch (binding) {
  ResolvedBinding(:final value?) => '$value',
  _ => '',
};

final class const _Text(final String text, {required final Object? variant})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final styles = TextTheme.of(context);
    return Text(
      text,
      // A body text keeps the style around it, such as a button's color.
      style: switch (variant) {
        TextVariant.h1 => styles.headlineMedium,
        TextVariant.h2 => styles.titleLarge,
        TextVariant.h3 => styles.titleMedium,
        TextVariant.caption => styles.bodySmall,
        _ => null,
      },
    );
  }
}

final class const _Button({
  required final Object? variant,
  required final VoidCallback? onPressed,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (variant) {
    ButtonVariant.primary => FilledButton(onPressed: onPressed, child: child),
    ButtonVariant.borderless => TextButton(onPressed: onPressed, child: child),
    _ => OutlinedButton(onPressed: onPressed, child: child),
  };
}
