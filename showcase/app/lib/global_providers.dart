import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// What every screen of the app reads, for the app's life.
final class const GlobalProviders({
  super.key,

  /// Called once: another connection starts another session.
  required final Agents Function() createAgents,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider(create: (context) => createAgents()),
      RepositoryProvider(create: (context) => const Inbox()),
      RepositoryProvider(create: (context) => const ArrivalDays()),
      RepositoryProvider(create: (context) => const FlightSearch()),
      RepositoryProvider(create: (context) => const HotelSearch()),
      RepositoryProvider(create: (context) => demoTraveller()),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TripsCubit(demoTrips(), inbox: context.read()),
        ),
        BlocProvider(create: (context) => ReportsCubit(inbox: context.read())),
      ],
      child: child,
    ),
  );
}
