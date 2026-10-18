import 'package:example/recipes/fill_from_email/contact_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// A contact form that the agent fills in from a pasted e-mail. A button
/// talks to the agent, and there is no chat.
final class const ContactScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ContactCubit(),
    child: TandemScope.connected(
      surface: (context) => context.read<ContactCubit>(),
      connection: connection,
      approvals: const .none(),
      onEvent: (context, event, session) {
        final problem = switch (event) {
          RunFailed() => 'The agent ran into a problem. Try again.',
          ConnectionLost() => 'The connection to the agent broke. Try again.',
          AgentCall() || RunStopped() => null,
        };
        if (problem case final text?) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(text)));
        }
      },
      child: const Scaffold(body: _ContactForm()),
    ),
  );
}

final class const _ContactForm() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ContactCubit>();
    final contact = cubit.contact;

    return ListView(
      padding: const .all(16),
      children: [
        const _FillFromEmail(),
        _Field('Name', contact.name, cubit.setName),
        _Field('E-mail', contact.email, cubit.setEmail),
        _Field('Company', contact.company, cubit.setCompany),
      ],
    );
  }
}

final class const _FillFromEmail() extends StatefulWidget {
  @override
  State<_FillFromEmail> createState() => _FillFromEmailState();
}

final class _FillFromEmailState() extends State<_FillFromEmail> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final progress = switch (session.status) {
      Idle() || AwaitingApproval() => null,
      Thinking() || Stopping() => 'Reading the e-mail…',
      Calling() => 'Filling in the form…',
    };
    final reply = session.items.whereType<AgentMessage>().lastOrNull;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        TextField(
          controller: _email,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Pasted e-mail'),
        ),
        FilledButton(
          onPressed: progress == null
              ? () => session.send(
                  'Fill in the contact from this e-mail:\n\n${_email.text}',
                )
              : null,
          child: const Text('Fill from e-mail'),
        ),
        if (progress case final text?) ...[
          const LinearProgressIndicator(),
          Text(text),
        ] else if (reply case AgentMessage(:final text))
          Text(text),
      ],
    );
  }
}

final class const _Field(
  final String label,
  final String value,
  final ValueChanged<String> onChanged,
) extends StatefulWidget {
  @override
  State<_Field> createState() => _FieldState();
}

final class _FieldState() extends State<_Field> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The agent changed the value. What the user types matches it already.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
  );
}
