import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/arrival/arrival_action.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('the approval tools of the arrival read as their actions', () {
    final day = const ArrivalDays().of(TripId('berlin'));
    if (day == null) {
      fail('Berlin has no arrival day.');
    }
    final arrangements = ArrivalArrangementsCubit();
    addTearDown(arrangements.close);
    final trips = TripsCubit(demoTrips(), inbox: const Inbox());
    addTearDown(trips.close);
    final arrival = ArrivalCubit(
      tripId: TripId('berlin'),
      trips: trips,
      day: day,
      arrangements: arrangements,
    );
    addTearDown(arrival.close);

    final actions = [
      for (final tool in arrival.agentSchema.calls)
        ?ArrivalAction.of(tool.name, {
          for (final parameter in tool.parameters) parameter.name: ' taxi ',
        }),
    ];

    expect(actions, [
      isA<BookRide>().having(
        (action) => action.rideId,
        'rideId',
        RideId('taxi'),
      ),
      isA<MessageHost>(),
    ]);
  });
}
