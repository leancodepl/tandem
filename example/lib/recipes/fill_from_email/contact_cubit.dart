import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

part 'contact_cubit.g.dart';

class const ContactState({
  final String name = '',
  final String email = '',
  final String company = '',
}) {
  ContactState copyWith({String? name, String? email, String? company}) => .new(
    name: name ?? this.name,
    email: email ?? this.email,
    company: company ?? this.company,
  );
}

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
