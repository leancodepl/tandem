import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
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
  return const [AgentStep.say('Filled in from the confirmation.')];
}

/// One call per field the e-mail gives.
List<AgentStep> _fill(String email) {
  String? line(String label) =>
      RegExp('^$label: (.+)\$', multiLine: true).firstMatch(email)?[1];

  final confirmation = line('Confirmation number');
  if (confirmation == null) {
    return const [];
  }
  final lines = email.trimRight().split('\n');
  return [
    if (RegExp('^From: (.+?) <', multiLine: true).firstMatch(email)?[1]
        case final hotel?)
      AgentStep.callTool('set_hotel', {'name': hotel}),
    // A hotel signs with its name and its address, the last line.
    AgentStep.callTool('set_address', {'address': lines.last.trim()}),
    if (_date(line('Check-in')) case final day?)
      AgentStep.callTool('set_check_in', {
        'at': '${day}T${_time(line('Check-in')) ?? '15:00'}:00',
      }),
    if (_date(line('Check-out')) case final day?)
      AgentStep.callTool('set_check_out', {'day': day}),
    if (RegExp(r'EUR (\d+)').firstMatch(line('Total') ?? '')?[1]
        case final euros?)
      AgentStep.callTool('set_total_price', {'euros': int.parse(euros)}),
    AgentStep.callTool('set_confirmation', {'number': confirmation}),
  ];
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Wednesday, 18 November 2026, from 15:00" as 2026-11-18.
String? _date(String? text) {
  final match = RegExp(r'(\d{1,2}) (\w+) (\d{4})').firstMatch(text ?? '');
  if (match == null) {
    return null;
  }
  final month = _months.indexOf(match[2] ?? '') + 1;
  final day = (match[1] ?? '').padLeft(2, '0');
  return '${match[3]}-${month.toString().padLeft(2, '0')}-$day';
}

String? _time(String? text) =>
    RegExp(r'\d{2}:\d{2}').firstMatch(text ?? '')?[0];
