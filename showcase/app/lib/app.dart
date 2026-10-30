import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/global_providers.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint/navigation/navigation_log.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

final class const WaypointApp({
  super.key,
  required final Agents Function() createAgents,

  /// Wraps every screen, such as with an overlay for recordings.
  final TransitionBuilder? builder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GlobalProviders(
    createAgents: createAgents,
    child: AppCore(builder: builder),
  );
}

/// The router and the app on it, under the global providers.
final class const AppCore({super.key, final TransitionBuilder? builder})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final router = useMemoized(AppRouter.new);
    useEffect(() => router.dispose, [router]);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        DesignSystemLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: waypointTheme(),
      builder: builder,
      routerConfig: router.config(navigatorObservers: () => [NavigationLog()]),
    );
  }
}
