import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Trip');

/// Tells the agent, when the trip opens, about each forwarded e-mail that
/// moves a meeting the trip does not follow yet, and wakes it to fit the
/// trip around the change. The traveller then only approves.
final class const NewsForAgent({super.key, required final Widget child})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    useEffect(() {
      // Once the session is in scope: it starts with the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _tellAgent(context);
        }
      });
      return null;
    }, const []);

    return child;
  }

  static void _tellAgent(BuildContext context) {
    final trip = context.read<TripCubit>();
    final notes = [
      for (final email in context.read<TripsCubit>().news(trip.info.id))
        if (email.news case MeetingMoved(:final meetingId, :final start))
          _note(email, trip.itinerary.meeting(meetingId)?.title, start),
    ];
    if (notes.isEmpty) {
      return;
    }

    _log.fine('Told the agent of ${notes.length} moved meetings');
    final session = TandemSessionScope.of(context);
    notes.forEach(session.note);
    session.wake();
  }

  static String _note(ForwardedEmail email, String? meeting, DateTime start) =>
      'The traveller forwarded an e-mail from ${email.from}: it moves '
      '${meeting ?? 'a meeting'} to ${forAgent(start)}. The trip on the '
      'screen still has the old time. The e-mail:\n${email.body}';
}
