import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

/// The app's tabs: a bar at the bottom on a phone, a rail on an iPad.
@RoutePage()
final class const HomePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    builder: (context, child) {
      final tabs = AutoTabsRouter.of(context);
      final unread = context.select<TripsCubit, int>((trips) => trips.waiting);
      final reports = context.watch<ReportsCubit>();
      final toSubmit = context
          .select<TripsCubit, List<String>>(
            (trips) => [for (final trip in trips.state.trips) trip.id],
          )
          .where(reports.waits)
          .length;
      final l10n = context.l10n;

      return WaypointNavigationScaffold(
        selectedIndex: tabs.activeIndex,
        onSelected: tabs.setActiveIndex,
        destinations: [
          WaypointDestination(
            Icons.luggage_outlined,
            Icons.luggage_rounded,
            l10n.tabTrips,
          ),
          WaypointDestination(
            Icons.mail_outline_rounded,
            Icons.mail_rounded,
            l10n.tabInbox,
            count: unread,
          ),
          WaypointDestination(
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            l10n.tabExpenses,
            count: toSubmit,
          ),
        ],
        child: child,
      );
    },
  );
}
