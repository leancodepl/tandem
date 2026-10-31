import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('policy summaries and breach text preserve the agent format', () {
    const flights = FlightSearch();
    final day = DateTime(2026, 12, 9);
    final outbound = flights.find(FlightNumber('WA 511'), day);
    final homebound = flights.find(FlightNumber('WA 518'), day);
    if (outbound == null || homebound == null) {
      fail('The Vienna flights are in the timetable.');
    }
    final meeting = Meeting(
      id: MeetingId('workshop'),
      title: 'Discovery workshop',
      place: 'Alpenlicht, Mariahilfer Str. 88',
      start: DateTime(2026, 12, 9, 9, 5),
      end: DateTime(2026, 12, 9, 18, 5),
    );
    final cases = <({String label, String actual, String expected})>[
      (
        label: 'trip policy',
        actual: PolicyAgentText.trip,
        expected:
            'Economy flights. Hotels up to €160 a night. Arrive the evening '
            'before a meeting that starts before 12:00. Fly home at '
            'least an hour after the last meeting ends.',
      ),
      (
        label: 'expense policy',
        actual: PolicyAgentText.expenses,
        expected:
            'Meals are paid back up to €60 a day. Taxis and public '
            'transport are paid back in full. Every expense needs its receipt.',
      ),
      (
        label: 'ride policy',
        actual: PolicyAgentText.rides,
        expected:
            'A taxi only when public transport would make the traveller late for '
            'the meeting.',
      ),
      (
        label: 'lands on meeting day',
        actual: LandsOnMeetingDay(outbound, meeting).forAgent,
        expected: 'WA 511 lands on the day of the Discovery workshop, which starts before 12:00',
      ),
      (
        label: 'lands too late',
        actual: LandsTooLate(outbound, meeting).forAgent,
        expected: 'WA 511 lands too late for the Discovery workshop',
      ),
      (
        label: 'leaves too early',
        actual: LeavesTooEarly(homebound, meeting).forAgent,
        expected:
            'WA 518 leaves less than an hour after the Discovery workshop ends',
      ),
      (
        label: 'over nightly limit',
        actual: OverNightly(wholeMoney(189)).forAgent,
        expected: 'Over the policy: €189 a night, the limit is €160',
      ),
      (
        label: 'over daily meal limit',
        actual: OverMealsPerDay(wholeMoney(18)).forAgent,
        expected:
            'Meals are paid back up to €60 a day, and €18 is left for that day',
      ),
      (
        label: 'taxi not needed',
        actual: TaxiNotNeeded(
          trainArrives: DateTime(2026, 12, 9, 9, 2),
          meetingStarts: meeting.start,
        ).forAgent,
        expected:
            'The S-Bahn gets the traveller there at 09:02, in time '
            'for 09:05: the policy allows a taxi only when public '
            'transport would make them late',
      ),
    ];

    for (final (:label, :actual, :expected) in cases) {
      expect(actual, expected, reason: label);
    }
  });
}
