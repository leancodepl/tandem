import 'package:advanced_forms/advanced_forms.dart';

/// The cities Waypoint flies to, by their airport.
const tripAirports = {'Berlin': 'BER', 'Copenhagen': 'CPH', 'Vienna': 'VIE'};

/// What the traveller sets of a new trip: where it goes and what it is for.
final class PlanTripFormController() extends AdvancedFormController {
  this : super(validationMode: .onUserInteraction) {
    registerFields([city, purpose]);
  }

  final city = AdvancedSingleSelectFieldController<String, Never>(
    initialValue: null,
    options: tripAirports.keys.toList(),
  );
  final purpose = AdvancedTextFieldController<Never>();
}
