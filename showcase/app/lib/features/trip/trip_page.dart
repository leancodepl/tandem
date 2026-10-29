import 'package:auto_route/auto_route.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity_cubit.dart';
import 'package:waypoint/features/trip/trip_approval_card.dart';
import 'package:waypoint/features/trip/trip_assistant_panel.dart';
import 'package:waypoint/features/trip/trip_changes_bar.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_header.dart';
import 'package:waypoint/features/trip/trip_item_keys.dart';
import 'package:waypoint/features/trip/trip_itinerary.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
import 'package:waypoint/features/trip/trip_news_for_agent.dart';
import 'package:waypoint/features/trip/trip_reasker.dart';
import 'package:waypoint/features/trip/trip_reasks_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_unknown_trip.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Trip');

/// The trip and its assistant: side by side on an iPad, the assistant docked
/// under the trip on a phone.
@RoutePage()
final class const TripPage({
  super.key,
  @PathParam() required final String tripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (context
      .select<TripsCubit, Trip?>((trips) => trips.tripOrNull(tripId))) {
    final trip? => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TripCubit(
            info: trip,
            trips: context.read(),
            flights: context.read(),
            traveller: context.read(),
          ),
        ),
        BlocProvider(create: (context) => MarksCubit()),
        BlocProvider(create: (context) => ActivityCubit()),
        BlocProvider(create: (context) => ReasksCubit()),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider(create: (context) => ItemKeys()),
          RepositoryProvider(create: (context) => AskedChanges()),
        ],
        child: Builder(
          builder: (context) => TandemScope.connected(
            surface: (context) => context.read<TripCubit>(),
            connection: context.watch<Agents>().trip,
            approvals: const .fromState(),
            onEvent: _onEvent,
            child: const _TripContent(),
          ),
        ),
      ),
    ),
    null => const UnknownTrip(),
  };

  static void _onEvent(
    BuildContext context,
    TandemEvent event,
    TandemSession session,
  ) {
    _log.agentEvent(event);
    if (event case AgentCall(:final tool, :final arguments)) {
      if (TripAction.of(tool, arguments) case final action?) {
        context.read<ActivityCubit>().add(
          action,
          context.read<TripCubit>(),
          session.items.length,
        );
        context.read<MarksCubit>().markAction(action);
      }
    }
  }
}

final class const _TripContent() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => NewsForAgent(
    child: Reasker(
      child: BlocPresentationListener<MarksCubit, MarksPresentationEvent>(
        listener: _revealChanged,
        child: WaypointPage(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The assistant beside the trip on a tablet, and the days side by
              // side once there is room for them next to it.
              final beside = constraints.maxWidth >= Widths.readable;
              final wide =
                  constraints.maxWidth - Widths.sidePanel >= Widths.readable;
              final trip = Column(
                crossAxisAlignment: .stretch,
                children: [
                  TripTopBar(wide: beside),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: SingleChildScrollView(
                        padding: .fromLTRB(
                          beside ? 36 : 20,
                          beside ? 8 : 0,
                          beside ? 36 : 20,
                          24,
                        ),
                        child: FlipArea(
                          child: Column(
                            crossAxisAlignment: .stretch,
                            children: [
                              TripHeader(wide: wide),
                              const TripNews(),
                              const ArrivalEntry(),
                              const TripWarnings(),
                              SizedBox(height: wide ? 22 : 10),
                              if (wide) const WaypointDivider(),
                              ItineraryView(wide: wide),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ChangesBar(wide: beside),
                ],
              );

              if (beside) {
                return Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(child: trip),
                    const WaypointDivider(vertical: true),
                    const SizedBox(
                      width: Widths.sidePanel - 1,
                      child: AssistantPanel(),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: .stretch,
                children: [
                  Expanded(child: trip),
                  const AssistantDock(),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  static void _revealChanged(
    BuildContext context,
    MarksPresentationEvent event,
  ) {
    final keys = context.read<ItemKeys>();
    switch (event) {
      case MarksPresentationEventItemChanged(:final id):
        // Once the card has moved and the days have settled.
        Future<void>.delayed(
          const Duration(milliseconds: 450),
          () => keys.reveal(id),
        );
    }
  }
}
