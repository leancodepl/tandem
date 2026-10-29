/// Waypoint's agents as scripts that stand in for the model. Like a model,
/// each decides from the run's request: what the traveller wrote, what the
/// screen shows and what the app answered. They know the Berlin trip: the
/// workshop that moves to Friday and the hotel's confirmation e-mail.
library;

export 'src/arrival_script.dart' show scriptedArrivalAgent;
export 'src/booking_script.dart' show scriptedBookingAgent;
export 'src/expenses_script.dart' show scriptedExpensesAgent;
export 'src/plan_script.dart' show scriptedPlanAgent;
export 'src/trip_script.dart' show scriptedTripAgent;
