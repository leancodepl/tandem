import 'package:example/recipes/fill_from_email/contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:tandem/testing.dart';

// Plays the same turns whatever the e-mail says. A run past the script fails.
final _agent = ScriptedAgent([
  (_) => const [
    AgentStep.callTool('set_name', {'name': 'Marta Nowak'}),
    AgentStep.callTool('set_email', {'email': 'marta@acme.example'}),
    AgentStep.callTool('set_company', {'company': 'Acme Office Supply'}),
  ],
  (_) => const [AgentStep.say('Filled in from the signature.')],
]);

void main() => runApp(MaterialApp(home: ContactScreen(connection: _agent)));
