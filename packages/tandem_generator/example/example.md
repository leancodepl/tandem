A Cubit with `@TandemAgent()` lists what the agent sees and calls. It is from the [examples of tandem](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#fill-from-e-mail):

<!-- example/lib/recipes/fill_from_email/contact_cubit.dart -->

```dart
@TandemAgent()
class ContactCubit() extends Cubit<ContactState> with _$ContactCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(contact),
    .calls(setName),
    .calls(setEmail),
    .calls(setCompany),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// The contact as the user sees it in the form.
  ContactState get contact => state;

  /// Sets the person's full name.
  void setName(String name) => emit(state.copyWith(name: name));

  /// Sets the person's e-mail address.
  void setEmail(String email) => emit(state.copyWith(email: email));

  /// Sets the company the person works for.
  void setCompany(String company) => emit(state.copyWith(company: company));
}
```

`dart run build_runner build` writes the `_$ContactCubit` mixin into `contact_cubit.g.dart`. Its `agentSchema` gives each `.sees` its name, doc comment and JSON:

<!-- example/lib/recipes/fill_from_email/contact_cubit.g.dart -->

```dart
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
```

And each method its name in snake_case, doc comment, JSON Schema and a call with the agent's arguments:

<!-- example/lib/recipes/fill_from_email/contact_cubit.g.dart -->

```dart
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
```

How an app uses it, from the scope to the chat: the [example of tandem](https://pub.dev/packages/tandem/example) and its [README](https://pub.dev/packages/tandem).
