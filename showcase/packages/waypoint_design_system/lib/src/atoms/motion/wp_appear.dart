import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Grows, fades and slides its child into place when it first shows, if
/// [enabled].
final class const WPAppear({
  super.key,
  required final bool enabled,
  required final Widget child,
}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 520),
      initialValue: enabled ? 0 : 1,
    );
    useEffect(() {
      controller.forward();
      return null;
    }, const []);
    final curve = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    return SizeTransition(
      sizeFactor: curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .12),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      ),
    );
  }
}

/// Fades and slides its child in when it first shows.
final class const WPSlideIn({super.key, required final Widget child})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 360),
    );
    useEffect(() {
      controller.forward();
      return null;
    }, const []);
    final curve = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .3),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
