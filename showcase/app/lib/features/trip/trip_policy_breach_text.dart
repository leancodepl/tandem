import 'package:intl/intl.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

extension PolicyBreachText on AppLocalizations {
  /// What [breach] breaks of the policy, as the screens say it.
  String policyBreach(PolicyBreach breach) => switch (breach) {
    LandsOnMeetingDay(:final flight, :final meeting) => breachLandsOnMeetingDay(
      flight.number,
      meeting.title,
      policyMorningUntil,
    ),
    LandsTooLate(:final flight, :final meeting) => breachLandsTooLate(
      flight.number,
      meeting.title,
    ),
    LeavesTooEarly(:final flight, :final meeting) => breachLeavesTooEarly(
      flight.number,
      meeting.title,
    ),
    OverNightly(:final nightly) => breachOverNightly(
      euros(nightly),
      euros(Policy.maxNightly),
    ),
    OverMealsPerDay(:final left) => breachOverMealsPerDay(
      euros(Policy.mealsPerDay),
      euros(left),
    ),
    TaxiNotNeeded(:final trainArrives, :final meetingStarts) =>
      breachTaxiNotNeeded(time(trainArrives), time(meetingStarts)),
  };

  /// 09:00, the [Policy.morningUntil] hour.
  String get policyMorningUntil =>
      DateFormat.Hm(localeName).format(DateTime(0, 1, 1, Policy.morningUntil));
}
