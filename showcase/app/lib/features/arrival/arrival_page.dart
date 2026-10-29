import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/arrival/arrival_action.dart';
import 'package:waypoint/features/arrival/arrival_catalog.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_unknown_trip.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Arrival');

/// The traveller's arrival day, which the agent draws with Waypoint's own
/// widgets. The view's buttons call the screen's methods, with the same
/// approvals as the agent's calls.
@RoutePage()
final class const ArrivalPage({
  super.key,
  @PathParam() required final String tripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch ((
    context.select<TripsCubit, Trip?>((trips) => trips.tripOrNull(tripId)),
    context.watch<ArrivalDays>().of(tripId),
  )) {
    (final trip?, final day?) => BlocProvider(
      create: (context) => ArrivalCubit(trip: trip, day: day),
      child: Builder(
        builder: (context) => TandemScope.connected(
          surface: (context) => context.read<ArrivalCubit>(),
          connection: context.watch<Agents>().arrival,
          approvals: const .fromState(),
          onEvent: _onEvent,
          child: const _ArrivalContent(),
        ),
      ),
    ),
    (null, _) => const UnknownTrip(),
    (_, null) => ErrorView(
      context.l10n.noArrivalDay,
      back: context.l10n.backToTrip,
      onBack: () => context.router.navigate(TripRoute(tripId: tripId)),
    ),
  };

  static void _onEvent(
    BuildContext context,
    TandemEvent event,
    TandemSession session,
  ) {
    _log.agentEvent(event);
    // A view's action does not wake the agent: here it should answer.
    if (event case AgentCall(caller: .view)) {
      session.wake();
    }
  }
}

final class const _ArrivalContent() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const WaypointPage(child: _DayForAgent(child: _Arrival()));
}

/// Asks the agent, when the screen opens, to draw the day.
final class const _DayForAgent({required final Widget child})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    useEffect(() {
      // Once the session is in scope: it starts with the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _log.fine('Asked the agent to draw the arrival day');
          TandemSessionScope.of(context)
            ..note(
              'The traveller opened their arrival day. Draw what they need '
              'from landing to the first meeting.',
            )
            ..wake();
        }
      });
      return null;
    }, const []);

    return child;
  }
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
        WaypointTopBar(
          trailing: trip.purpose ?? l10n.clientWork,
          onBack: context.router.maybePop,
        ),
        Expanded(
          child: Readable(
            child: ListView(
              padding: const .fromLTRB(20, 0, 20, 24),
              children: [
                WaypointPageTitle(
                  trip.city.toUpperCase(),
                  below: l10n.arrivalDate(
                    l10n.day(cubit.lands),
                    l10n.time(cubit.lands),
                  ),
                ),
                switch (session.failure) {
                  final failure? => InlineError(
                    l10n.agentFailure(failure),
                    onRetry: session.retry,
                  ),
                  null => WorkStatus(
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
        const SafeArea(
          top: false,
          child: Readable(
            child: Padding(
              padding: .fromLTRB(16, 8, 16, 12),
              child: _ArrivalComposer(),
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
          final ride? => askBookRide(ride.mode.name, euros(ride.fare)),
          null => approvalFallback,
        },
        MessageHost() => askMessageHost(day.host.name),
        null => approvalFallback,
      };
}

/// What a button of the view or the agent asks to do in the traveller's
/// name, to approve or reject.
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
        final request? => WaypointActionBar(
          active: true,
          bottom: false,
          child: WaypointApproval(
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
      // The day changed as the traveller tapped; the agent asks again.
      _log.warning('$error');
    }
  }
}

/// The composer, bound to the arrival day's session.
final class const _ArrivalComposer() extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final text = useTextEditingController();
    final session = TandemSessionScope.of(context);
    final status = session.status;
    return WaypointComposer(
      controller: text,
      hint: context.l10n.arrivalComposerHint,
      working: status.isRunning,
      onSend: () {
        session.send(text.text);
        text.clear();
        // On a phone the keyboard would hide the day the assistant draws.
        FocusScope.of(context).unfocus();
      },
      onStop: status.isStoppable ? session.stop : null,
    );
  }
}
