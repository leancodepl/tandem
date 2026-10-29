import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The expense reports of the trips that are over, the ones to submit
/// first.
@RoutePage(name: 'ExpensesRoute')
final class const ExpensesListPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = context.watch<Traveller>().today;
    final past = context.select<TripsCubit, List<Trip>>(
      (trips) => [
        for (final trip in trips.state.trips)
          if (trip.isPastOn(today)) trip,
      ],
    );
    final reports = context.watch<ReportsCubit>();
    final l10n = context.l10n;

    return WaypointTabPage(
      title: l10n.expensesTitle,
      above: l10n.expensesAbove,
      children: [
        if (past.isEmpty) Text(l10n.expensesNone, style: AppText.label),
        for (final trip in past)
          Padding(
            padding: const .only(bottom: 12),
            child: _ReportCard(trip, reports: reports),
          ),
      ],
    );
  }
}

final class const _ReportCard(
  final Trip trip, {
  required final ReportsCubit reports,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final report = reports.report(trip.id);
    final receipts = reports.receipts(trip.id).length;
    final l10n = context.l10n;
    final status = switch (report.submitted) {
      final confirmation? => WaypointNote(
        Icons.check_rounded,
        l10n.reportSubmittedLine(l10n.euros(report.total), confirmation),
      ),
      null => WaypointNote(
        Icons.receipt_long_rounded,
        l10n.reportToSubmit(receipts),
        tone: .ai,
      ),
    };

    return WaypointListCard(
      onTap: () =>
          context.router.navigate(ExpensesReportRoute(tripId: trip.id)),
      border: report.submitted == null ? Palette.aiLine : Palette.line,
      title: trip.city.toUpperCase(),
      subtitle: l10n.dayRange(
        trip.booked.outbound.departs,
        trip.booked.homebound.departs,
      ),
      caption: trip.purpose ?? l10n.clientWork,
      footer: [status],
    );
  }
}
