import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity_cubit.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
import 'package:waypoint/features/trip/trip_reasks_cubit.dart';

void main() {
  late MarksCubit marks;

  setUp(() => marks = MarksCubit());

  tearDown(() => marks.close());

  test('trip UI snapshots own their state collections', () {
    final ids = {'hotel'};
    final steps = <AgentStep>[const FlightsLookedUpStep(1)];
    final toolCalls = {'call-1'};
    final marks = MarksState(ids);
    final activity = ActivityState(steps);
    final reasks = ReasksState(toolCalls);

    ids.clear();
    steps.clear();
    toolCalls.clear();

    expect(marks.ids, {'hotel'});
    expect(activity.steps, [const FlightsLookedUpStep(1)]);
    expect(reasks.toolCallIds, {'call-1'});
    for (final clear in [
      marks.ids.clear,
      activity.steps.clear,
      reasks.toolCallIds.clear,
    ]) {
      expect(clear, throwsUnsupportedError);
    }
  });

  test('a change of the agent marks its item and shows it', () async {
    final shown = <String>[];
    final listening = marks.presentation.listen(
      (event) => switch (event) {
        MarksPresentationEventItemChanged(:final id) => shown.add(id),
      },
    );

    for (final (tool, arguments) in [
      ('move_meeting', {'meetingId': ' workshop '}),
      ('set_hotel_nights', {'nights': 2}),
      ('find_flights', {'origin': 'BER', 'destination': 'WAW'}),
      ('set_homebound_flight', {'number': 'WA 388'}),
    ]) {
      marks.markAction(_action(tool, arguments));
    }
    await Future<void>.delayed(Duration.zero);
    await listening.cancel();

    expect(marks.state.ids, {'workshop', 'hotel', 'homebound'});
    expect(shown, ['workshop', 'hotel', 'homebound']);
  });

  test('booking the changes clears the marks', () {
    marks
      ..markAction(_action('set_hotel_nights'))
      ..markAction(_action('book_changes'));

    expect(marks.state.ids, isEmpty);
  });
}

TripAction _action(String tool, [Map<String, Object?> arguments = const {}]) =>
    switch (TripAction.of(tool, arguments)) {
      final action? => action,
      null => fail('$tool is not a tool of the trip.'),
    };
