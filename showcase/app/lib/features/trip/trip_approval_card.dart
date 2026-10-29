import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_changes_bar.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_reasks_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

final _log = Logger('Trip');

/// What each approval asked to book, kept by its call's id: the list builds
/// a card again whenever an item comes before it.
final class AskedChanges() {
  final _asked = <String, List<BookingChange>>{};

  List<BookingChange> of(ApprovalRequest request, TripCubit trip) =>
      _asked.putIfAbsent(request.toolCallId, () => trip.bookingChanges);
}

/// The approval of [TripCubit.bookChanges]: what the assistant asked to book,
/// as the screen was when it asked.
final class const ApprovalCard(final ApprovalRequest request, {super.key})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // Kept from when the card first showed: an invalidated card still shows
    // what was asked.
    final changes = useMemoized(
      () => context.read<AskedChanges>().of(request, context.read<TripCubit>()),
    );
    final cost = changes.fold(0, (sum, change) => sum + change.cost);
    final session = TandemSessionScope.of(context);
    final status = request.status;
    final pending = status == .pending;
    final void_ = status == .invalidated;
    final struck = void_ || status == .rejected || status == .cancelled;
    final strike = struck ? AppText.struck : null;
    final l10n = context.l10n;

    return WaypointCard(
      border: pending ? Palette.ai : Palette.line,
      padding: const .fromLTRB(16, 14, 16, 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: .topCenter,
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 10,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 360),
              opacity: struck ? .55 : 1,
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: 8,
                children: [
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Expanded(
                        child: Text(switch (TripAction.of(request.tool)) {
                          BookChanges() => l10n.changeBookings(changes.length),
                          _ => l10n.approvalFallback,
                        }, style: AppText.title.merge(strike)),
                      ),
                      Text(
                        l10n.eurosDelta(cost),
                        style: AppText.title.merge(strike),
                      ),
                    ],
                  ),
                  for (final change in changes)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.bookingChange(change),
                            style: AppText.label,
                          ),
                        ),
                        Text(
                          l10n.eurosDelta(change.cost),
                          style: AppText.label,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            switch (status) {
              .pending => WaypointDecision(
                onApprove: () => _decide(() => session.approve(request)),
                onReject: () => _decide(() => session.reject(request)),
              ),
              .invalidated => _VoidedLine(request),
              .approved => WaypointNote(Icons.check_rounded, l10n.approved),
              .rejected => WaypointNote(Icons.close_rounded, l10n.rejected),
              .cancelled => WaypointNote(
                Icons.close_rounded,
                l10n.cancelledByMessage,
              ),
            },
          ],
        ),
      ),
    );
  }
}

void _decide(void Function() decision) {
  try {
    decision();
  } on ApprovalNotPending catch (error) {
    // The trip changed as the traveller tapped. The card says so.
    _log.warning('$error');
  }
}

/// Why the request no longer counts, and what happens about it.
final class const _VoidedLine(final ApprovalRequest request)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final asked = context.select<ReasksCubit, bool>(
      (reasks) => reasks.state.contains(request),
    );
    final replaced = session.items
        .whereType<ApprovalRequest>()
        .skipWhile((item) => item.toolCallId != request.toolCallId)
        .skip(1)
        .isNotEmpty;
    final working = session.status.isWorking;
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: const Interval(.5, 1),
      switchOutCurve: const Interval(.5, 1),
      layoutBuilder: (current, previous) =>
          Stack(alignment: .topLeft, children: [...previous, ?current]),
      child: switch ((asked, replaced, working)) {
        (_, true, _) => WaypointNote(
          Icons.arrow_downward_rounded,
          l10n.approvalReplaced,
          key: const ValueKey('replaced'),
        ),
        (true, _, true) => WorkStatus(
          l10n.approvalUpdating,
          key: const ValueKey('updating'),
          working: true,
        ),
        _ => WaypointNote(
          Icons.info_outline_rounded,
          l10n.approvalVoided,
          key: const ValueKey('voided'),
        ),
      },
    );
  }
}

extension on AppLocalizations {
  String bookingChange(BookingChange change) => switch (change) {
    HotelNightsChange(:final hotel) => changeHotelNights(
      hotel.name,
      hotel.nights,
    ),
    FlightHomeChange(:final flight) => changeFlightHome(flight.number),
  };
}
