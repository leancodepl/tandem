// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ContactCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ContactCubit;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.contact,
          'contact',
          'The contact as the user sees it in the form.',
          (contact) => {
            'name': contact.name,
            'email': contact.email,
            'company': contact.company,
          },
        ),
      ],
      calls: [
        AgentTool(
          surface.setName,
          name: 'set_name',
          description: "Sets the person's full name.",
          parameters: const {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
            'required': ['name'],
          },
          invoke: (args) {
            surface.setName(args.read('name'));
            return null;
          },
        ),
        AgentTool(
          surface.setEmail,
          name: 'set_email',
          description: "Sets the person's e-mail address.",
          parameters: const {
            'type': 'object',
            'properties': {
              'email': {'type': 'string'},
            },
            'required': ['email'],
          },
          invoke: (args) {
            surface.setEmail(args.read('email'));
            return null;
          },
        ),
        AgentTool(
          surface.setCompany,
          name: 'set_company',
          description: 'Sets the company the person works for.',
          parameters: const {
            'type': 'object',
            'properties': {
              'company': {'type': 'string'},
            },
            'required': ['company'],
          },
          invoke: (args) {
            surface.setCompany(args.read('company'));
            return null;
          },
        ),
      ],
    );
  }
}
