import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/tandem/form_changes.dart';

void main() {
  test("changes reports the cubit's states, the form's values and its fields' "
      'errors', () async {
    final form = _NameForm();
    final cubit = _NameCubit(form: form);
    final events = <Object?>[];
    final done = Completer<void>();
    cubit.changes.listen(events.add, onDone: done.complete);

    Future<int> eventsOf(void Function() act) async {
      final before = events.length;
      act();
      await pumpEventQueue();
      return events.length - before;
    }

    expect(await eventsOf(() => form.name.setValue('Ada')), isPositive);
    expect(await eventsOf(() => form.name.setValue('Ada 2')), isPositive);
    expect(form.name.error, _NameError.digits);
    expect(await eventsOf(cubit.rename), 1);

    await cubit.close();
    form.dispose();
    expect(done.isCompleted, isTrue);
  });

  test('changes follows the form again after its last listener left', () async {
    final form = _NameForm();
    final cubit = _NameCubit(form: form);
    addTearDown(() async {
      await cubit.close();
      form.dispose();
    });

    await cubit.changes.listen((_) {}).cancel();
    form.name.setValue('Ada');
    final events = <Object?>[];
    cubit.changes.listen(events.add);
    form.name.setValue('Grace');
    await pumpEventQueue();

    expect(events, hasLength(1));
  });
}

enum _NameError() {
  digits,
}

final class _NameForm() extends AdvancedFormController {
  this : super(validationMode: .onUserInteraction) {
    registerFields([name]);
  }

  final name = AdvancedTextFieldController<_NameError>(
    validator: (text) =>
        text.contains(RegExp(r'\d')) ? _NameError.digits : null,
  );
}

final class _NameCubit({@override required final _NameForm form})
    extends Cubit<int>
    with FormChanges<int> {
  this : super(0);

  void rename() => emit(state + 1);
}
