import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// The content that cards move within, so that scrolling is not a move.
final class const FlipArea({super.key, required final Widget child})
    extends HookWidget {
  static RenderBox? of(BuildContext context) =>
      context
              .getInheritedWidgetOfExactType<_FlipAreaScope>()
              ?.area
              .currentContext
              ?.findRenderObject()
          as RenderBox?;

  @override
  Widget build(BuildContext context) {
    final area = useMemoized(GlobalKey.new);
    return _FlipAreaScope(
      area: area,
      child: KeyedSubtree(key: area, child: child),
    );
  }
}

final class const _FlipAreaScope({
  required final GlobalKey area,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_FlipAreaScope oldWidget) => area != oldWidget.area;
}

/// Glides its child from where it was to where it is when its [slot]
/// changes, such as a card that moves to another day. Give it a [GlobalKey]
/// so that it keeps its state when it moves to another parent.
final class const Flip({
  required GlobalKey super.key,
  required final Object slot,
  required final Widget child,
}) extends HookWidget {
  static const _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 700),
    );
    final probe = useMemoized(GlobalKey.new);
    final from = useRef(Offset.zero);
    Offset offset() => from.value * (1 - _curve.transform(controller.value));

    useValueChanged<Object, void>(slot, (_, _) {
      final painted = probe.currentContext?.findRenderObject() as _RenderProbe?;
      final was = painted?.position;
      final shown = offset();
      if (painted == null || was == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final area = context.mounted ? FlipArea.of(context) : null;
        if (area == null || !painted.attached || !painted.hasSize) {
          return;
        }
        final now = painted.localToGlobal(Offset.zero, ancestor: area);
        final delta = was + shown - now;
        if (delta.distance < 1) {
          return;
        }
        from.value = delta;
        controller.forward(from: 0);
      });
    });

    return _Probe(
      key: probe,
      area: () => FlipArea.of(context),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) =>
            Transform.translate(offset: offset(), child: child),
        child: child,
      ),
    );
  }
}

/// Remembers where it was painted, before any move of its child.
final class const _Probe({
  super.key,
  required final RenderBox? Function() area,
  super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  _RenderProbe createRenderObject(BuildContext context) => _RenderProbe(area);

  @override
  void updateRenderObject(BuildContext context, _RenderProbe renderObject) =>
      renderObject.area = area;
}

final class _RenderProbe(var RenderBox? Function() area)
    extends RenderProxyBox {
  Offset? position;

  @override
  void paint(PaintingContext context, Offset offset) {
    final ancestor = area();
    if (ancestor != null && ancestor.attached) {
      position = localToGlobal(Offset.zero, ancestor: ancestor);
    }
    super.paint(context, offset);
  }
}
