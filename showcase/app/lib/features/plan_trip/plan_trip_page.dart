import 'package:auto_route/auto_route.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/plan_trip/plan_trip_cubit.dart';
import 'package:waypoint/features/plan_trip/plan_trip_form_controller.dart';
import 'package:waypoint/features/trip/trip_policy_breach_text.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('PlanTrip');

/// A new trip that the agent plans from an invitation or the traveller's
/// words, within the company policy, without a chat. The traveller books
/// it with their own tap.
@RoutePage()
final class const PlanTripPage({
  super.key,

  /// The trip of the invitation in the inbox to plan from, if any.
  @QueryParam('invitation') final String? invitationTripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final invitation = switch (invitationTripId) {
      final tripId? => context.watch<Inbox>().invitation(tripId),
      null => null,
    };
    return switch ((invitationTripId, invitation)) {
      (_?, null) => ErrorView(
        context.l10n.unknownInvitation,
        back: context.l10n.yourTrips,
        onBack: () => context.router.navigate(const TripsRoute()),
      ),
      _ => ChangeNotifierProvider(
        create: (context) => PlanTripFormController(),
        child: BlocProvider(
          create: (context) => PlanTripCubit(
            trips: context.read<TripsCubit>(),
            flights: context.read(),
            hotels: context.read(),
            invitation: invitation,
            form: context.read<PlanTripFormController>(),
          ),
          child:
              BlocPresentationListener<
                PlanTripCubit,
                PlanTripPresentationEvent
              >(
                listener: _openBooked,
                child: Builder(
                  builder: (context) => TandemScope.connected(
                    surface: (context) => context.read<PlanTripCubit>(),
                    connection: context.watch<Agents>().plan,
                    approvals: const .none(),
                    onEvent: (context, event, session) =>
                        _log.agentEvent(event),
                    child: const _PlanTripContent(),
                  ),
                ),
              ),
        ),
      ),
    };
  }

  static void _openBooked(
    BuildContext context,
    PlanTripPresentationEvent event,
  ) {
    switch (event) {
      case PlanTripPresentationEventBooked(:final tripId):
        context.router.replace(TripRoute(tripId: tripId));
    }
  }
}

final class const _PlanTripContent() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointPage(
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        WaypointTopBar(
          title: context.l10n.planATrip,
          onBack: context.router.maybePop,
        ),
        const Expanded(child: _PlanTripForm()),
      ],
    ),
  );
}

final class const _PlanTripForm() extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PlanTripCubit>();
    final invitation = cubit.invitation;
    final words = useTextEditingController();
    final asked = useState(false);

    void ask(String text, TandemSession session) {
      asked.value = true;
      session.send(text);
    }

    useEffect(() {
      if (invitation == null) return null;

      // Once the session is in scope: it starts with the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ask(
            'Plan the trip for this invitation:\n\n${invitation.body}',
            TandemSessionScope.of(context),
          );
        }
      });
      return null;
    }, const []);

    final form = context.watch<PlanTripFormController>();
    useListenable(form.onValuesChanged);
    final session = TandemSessionScope.of(context);
    final plan = cubit.state;
    final missing = cubit.missing;
    final busy = session.status.isWorking;
    // Why the agent chose what it chose, in its own words.
    final said = switch (session.items.lastOrNull) {
      AgentMessage(:final text) when text.isNotEmpty => text,
      _ => null,
    };
    final l10n = context.l10n;
    final stillMissing = l10n.stillMissing(
      missing.map((part) => l10n.planPart(part.name)).join(l10n.listSeparator),
    );
    final status = switch ((busy, asked.value)) {
      (true, _) => switch (invitation) {
        _? => l10n.planFromInvitation,
        null => l10n.planPlanning,
      },
      (_, true) when missing.isEmpty => said ?? l10n.planPlanned,
      (_, true) => stillMissing,
      (_, false) when form.value.wasModified && missing.isNotEmpty =>
        stillMissing,
      _ => null,
    };
    final wide = MediaQuery.sizeOf(context).width >= Widths.wide;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: Readable(
            child: ListView(
              padding: .fromLTRB(20, wide ? 12 : 4, 20, 24),
              keyboardDismissBehavior: .onDrag,
              children: [
                switch (invitation) {
                  final invitation? => WaypointMailCard(
                    from: invitation.from,
                    subject: invitation.subject,
                  ),
                  null => _Words(
                    words,
                    onSend: busy || plan.booking
                        ? null
                        : () => ask(words.text.trim(), session),
                  ),
                },
                switch (session.failure) {
                  final failure? => InlineError(
                    l10n.agentFailure(failure),
                    onRetry: plan.booking ? null : session.retry,
                  ),
                  null => WorkStatus(status, working: busy),
                },
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: .stretch,
                  spacing: 18,
                  children: [
                    WaypointSection(
                      l10n.planTrip,
                      child: WaypointGroup(
                        children: [
                          FormSelectField(
                            field: form.city,
                            label: l10n.planCity,
                            optionLabel: (city) => city,
                            // The invitation's meetings are in its city.
                            enabled: !busy && invitation == null,
                            marked: plan.marked.contains(PlanTripInput.city),
                            order: 0,
                            onEdited: () => cubit.unmark(.city),
                          ),
                          FormTextField(
                            field: form.purpose,
                            label: l10n.planPurpose,
                            enabled: !busy,
                            textCapitalization: .sentences,
                            textInputAction: .done,
                            marked: plan.marked.contains(PlanTripInput.purpose),
                            order: 1,
                            onEdited: () => cubit.unmark(.purpose),
                          ),
                        ],
                      ),
                    ),
                    WaypointSection(
                      l10n.planMeetings,
                      child: FilledFields([
                        if (plan.meetings.isEmpty)
                          (l10n.planMeetingsField, null),
                        for (final meeting in plan.meetings)
                          (
                            meeting.title,
                            l10n.meetingTimes(
                              l10n.dayTime(meeting.start),
                              l10n.time(meeting.end),
                              meeting.place.split(',').first,
                            ),
                          ),
                      ]),
                    ),
                    WaypointSection(
                      l10n.planFlights,
                      child: FilledFields([
                        (l10n.planThere, l10n.flightLine(plan.outbound)),
                        (l10n.planHome, l10n.flightLine(plan.homebound)),
                      ]),
                    ),
                    WaypointSection(
                      l10n.planHotel,
                      child: FilledFields([
                        (
                          l10n.hotel,
                          switch ((plan.hotel, plan.nights)) {
                            (final hotel?, final nights?) => l10n.planHotelLine(
                              hotel.name,
                              nights,
                              l10n.euros(hotel.nightly),
                              hotel.walkMinutes,
                            ),
                            _ => null,
                          },
                        ),
                      ]),
                    ),
                    WaypointNote(
                      Icons.verified_user_outlined,
                      l10n.companyPolicy(
                        l10n.tripPolicy(
                          l10n.euros(Policy.maxNightly),
                          l10n.policyMorningUntil,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        WaypointActionBar(
          child: WaypointSubmit(
            label: plan.booking ? l10n.booking : l10n.bookTrip,
            busy: plan.booking,
            total: WaypointTotal(l10n.planTotal, l10n.euros(plan.total)),
            onSubmit: cubit.ready && !busy
                ? () async {
                    await cubit.book();
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

/// Where the traveller pastes an invitation or says where they go.
final class const _Words(
  final TextEditingController text, {
  required final VoidCallback? onSend,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: text,
    builder: (context, _) => WaypointTextField(
      controller: text,
      hint: context.l10n.planWordsHint,
      minLines: 2,
      maxLines: 8,
      trailing: WaypointButton(
        context.l10n.plan,
        small: true,
        onPressed: text.text.trim().isEmpty ? null : onSend,
      ),
    ),
  );
}

extension on AppLocalizations {
  String? flightLine(Flight? flight) => switch (flight) {
    final flight? => planFlightLine(
      flight.number,
      dayTime(flight.departs),
      time(flight.arrives),
      euros(flight.fare),
    ),
    null => null,
  };
}
