import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint_scripted_agent/src/booking_email.dart';
import 'package:waypoint_scripted_agent/src/last_user_text.dart';

/// The booking form's agent: it fills the form in from a hotel's
/// confirmation e-mail, in the form the demo's hotels write them.
AgentConnection scriptedBookingAgent() => ScriptedAgent.repeating(_booking);

List<AgentStep> _booking(Map<String, Object?> raw) {
  final request = AgentRequest(raw);
  if (request.isUserMessage) {
    final steps = _fill(lastUserText(raw));
    return steps.isEmpty
        ? const [AgentStep.say('This e-mail has no hotel booking.')]
        : steps;
  }
  final problems = [
    for (final result in request.latestToolResults) ?_toolProblem(result.value),
  ];
  return [
    AgentStep.say(
      problems.isEmpty
          ? 'Filled in from the confirmation.'
          : 'Some booking fields could not be filled in. ${problems.join(' ')}',
    ),
  ];
}

String? _toolProblem(Object? result) => switch (result) {
  {'status': final String status} when status != 'returned' => switch (result) {
    {'reason': final String reason} => reason,
    {'error': final String error} => error,
    _ => 'Check the fields on the form.',
  },
  _ => null,
};

List<AgentStep> _fill(String email) {
  final booking = BookingEmail.tryParse(email);
  if (booking == null) return const [];
  return [
    if (booking.hotelName case final name?)
      AgentStep.callTool('set_hotel', {'name': name}),
    if (booking.address case final address?)
      AgentStep.callTool('set_address', {'address': address}),
    if (booking.checkIn case final at?)
      AgentStep.callTool('set_check_in', {
        'at': at.toIso8601String().split('.').first,
      }),
    if (booking.checkOut case final day?)
      AgentStep.callTool('set_check_out', {
        'day': day.toIso8601String().split('T').first,
      }),
    if (booking.wholeEuros case final euros?)
      AgentStep.callTool('set_total_price', {'euros': euros}),
    AgentStep.callTool('set_confirmation', {
      'number': booking.confirmationNumber,
    }),
  ];
}
