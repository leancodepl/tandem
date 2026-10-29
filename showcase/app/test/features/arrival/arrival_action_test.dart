import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/arrival/arrival_action.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('the approval tools of the arrival read as their actions', () {
    final day = const ArrivalDays().of('berlin');
    if (day == null) {
      fail('Berlin has no arrival day.');
    }
    final arrival = ArrivalCubit(
      trip: demoTrips().singleWhere((trip) => trip.id == 'berlin'),
      day: day,
    );
    addTearDown(arrival.close);

    final actions = [
      for (final tool in arrival.agentSchema.calls)
        ?ArrivalAction.of(tool.name, {
          for (final parameter in tool.parameters) parameter.name: 'taxi',
        }),
    ];

    expect(actions, [
      isA<BookRide>().having((action) => action.rideId, 'rideId', 'taxi'),
      isA<MessageHost>(),
    ]);
  });
}
