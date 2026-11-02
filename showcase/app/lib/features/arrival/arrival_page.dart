import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_composer.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/arrival/arrival_action.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/arrival/arrival_catalog.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_unknown_trip.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Arrival');

@RoutePage()
final class const ArrivalPage({
  super.key,
  @PathParam() required final String tripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch ((
    context.select<TripsCubit, Trip?>(
      (trips) => trips.tripOrNull(TripId.tryParse(tripId)),
    ),
    switch (TripId.tryParse(tripId)) {
      final id? => context.watch<ArrivalDays>().of(id),
      null => null,
    },
  )) {
    (final trip?, final day?) => BlocProvider(
      create: (context) => ArrivalCubit(
        tripId: trip.id,
        trips: context.read<TripsCubit>(),
        day: day,
        arrangements: context.read<ArrivalArrangementsCubit>(),
      ),
      child: Builder(
        builder: (context) => TandemScope.connected(
          surface: (context) => context.read<ArrivalCubit>(),
          connection: context.watch<Agents>().arrival,
          approvals: const .fromState(),
          onEvent: (context, event, session) => _log.agentEvent(event),
          child: const Scaffold(body: _Arrival()),
        ),
      ),
    ),
    (null, _) => const UnknownTrip(),
    (_, null) => WPErrorView(
      context.l10n.noArrivalDay,
      backLabel: context.l10n.backToTrip,
      onBack: () => context.router.navigate(TripRoute(tripId: tripId)),
    ),
  };
}

final class const _Arrival() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ArrivalCubit>();
    final session = TandemSessionScope.of(context);
    final status = session.status;
    final busy = status.isWorking;
    final said = switch (session.items.whereType<AgentMessage>().lastOrNull) {
      AgentMessage(:final text) when text.isNotEmpty => text,
      _ => null,
    };
    final trip = cubit.trip;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        WPTopBar(
          trailing: trip.purpose ?? l10n.clientWork,
          onBack: context.router.maybePop,
        ),
        Expanded(
          child: WPReadable(
            child: ListView(
              padding: const .fromLTRB(20, 0, 20, 24),
              children: [
                WPPageTitle(
                  trip.city.toUpperCase(),
                  below: l10n.arrivalDate(
                    l10n.day(cubit.lands),
                    l10n.time(cubit.lands),
                  ),
                  trailing: WPButton(
                    l10n.arrivalPlanAction,
                    small: true,
                    onPressed: status is Idle
                        ? () => session.send(
                            'Plan my arrival from landing to the first meeting.',
                          )
                        : null,
                  ),
                ),
                switch (session.failure) {
                  final failure? => WPInlineError(
                    l10n.agentFailure(failure),
                    onRetry: session.retry,
                  ),
                  null => WPWorkStatus(
                    busy ? l10n.work(status) : said,
                    working: busy,
                  ),
                },
                const SizedBox(height: 18),
                const TandemView(catalog: ArrivalCatalog()),
              ],
            ),
          ),
        ),
        const _ApprovalBar(),
        SafeArea(
          top: false,
          child: WPReadable(
            child: Padding(
              padding: const .fromLTRB(16, 8, 16, 12),
              child: SessionComposer(hint: l10n.arrivalComposerHint),
            ),
          ),
        ),
      ],
    );
  }
}

extension on AppLocalizations {
  String work(SessionStatus status) => switch (status) {
    Calling(:final tool) when ArrivalAction.of(tool) is BookRide =>
      arrivalBookingRide,
    _ => arrivalPlanning,
  };

  String ask(ApprovalRequest request, ArrivalDay day) =>
      switch (ArrivalAction.of(request.tool, request.arguments)) {
        BookRide(:final rideId) => switch (day.rides
            .where((ride) => ride.id == rideId)
            .firstOrNull) {
          final ride? => askBookRide(ride.mode.name, money(ride.fare)),
          null => approvalFallback,
        },
        MessageHost() => askMessageHost(day.host.name),
        null => approvalFallback,
      };
}

final class const _ApprovalBar() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final cubit = context.watch<ArrivalCubit>();
    final request = session.items
        .whereType<ApprovalRequest>()
        .where((request) => request.status == .pending)
        .lastOrNull;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .bottomCenter,
      child: switch (request) {
        // The composer is below the bar.
        final request? => WPActionBar(
          active: true,
          includeBottomInset: false,
          child: WPApproval(
            context.l10n.ask(request, cubit.day),
            onApprove: () => _decide(() => session.approve(request)),
            onReject: () => _decide(() => session.reject(request)),
          ),
        ),
        null => const SizedBox(width: double.infinity),
      },
    );
  }

  void _decide(void Function() decision) {
    try {
      decision();
    } on ApprovalNotPending catch (error) {
      // The day changed as the traveller tapped.
      _log.warning('$error');
    }
  }
}
