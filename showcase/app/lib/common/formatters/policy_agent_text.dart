import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

abstract final class PolicyAgentText() {
  static final trip =
      'Economy flights. Hotels up to €${Policy.maxNightly.toInt()} a night. Arrive the evening '
      'before a meeting that starts before ${Policy.morningUntil}:00. Fly home at '
      'least an hour after the last meeting ends.';

  static final expenses =
      'Meals are paid back up to €${Policy.mealsPerDay.toInt()} a day. Taxis and public '
      'transport are paid back in full. Every expense needs its receipt.';

  static const rides =
      'A taxi only when public transport would make the traveller late for '
      'the meeting.';
}

extension PolicyBreachAgentText on PolicyBreach {
  String get forAgent => switch (this) {
    LandsOnMeetingDay(:final flight, :final meeting) =>
      '${flight.number} lands on the day of the ${meeting.title}, which '
          'starts before ${Policy.morningUntil}:00',
    LandsTooLate(:final flight, :final meeting) =>
      '${flight.number} lands too late for the ${meeting.title}',
    LeavesTooEarly(:final flight, :final meeting) =>
      '${flight.number} leaves less than an hour after the ${meeting.title} '
          'ends',
    OverNightly(:final nightly) =>
      'Over the policy: €${nightly.toInt()} a night, the limit is '
          '€${Policy.maxNightly.toInt()}',
    OverMealsPerDay(:final left) =>
      'Meals are paid back up to €${Policy.mealsPerDay.toInt()} a day, and €${left.toInt()} is '
          'left for that day',
    TaxiNotNeeded(:final trainArrives, :final meetingStarts) =>
      'The S-Bahn gets the traveller there at ${timeForAgent(trainArrives)}, in time '
          'for ${timeForAgent(meetingStarts)}: the policy allows a taxi only when public '
          'transport would make them late',
  };
}
