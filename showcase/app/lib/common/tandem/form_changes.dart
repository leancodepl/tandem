import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What a cubit that the agent sees with its [form] reports as its changes:
/// every state it emits and every change of a form value or of a field's
/// error.
mixin FormChanges<S> on Cubit<S> {
  AdvancedFormController get form;

  late final _formChanges = Listenable.merge([
    form.onValuesChanged,
    form.onStatusChanged,
  ]);

  late final _changes = StreamController<Object?>.broadcast(
    onListen: () => _formChanges.addListener(_formChanged),
    onCancel: () => _formChanges.removeListener(_formChanged),
  );

  Stream<Object?> get changes => _changes.stream;

  void _formChanged() => _changes.add(null);

  @override
  void onChange(Change<S> change) {
    super.onChange(change);
    _changes.add(change);
  }

  @override
  Future<void> close() async {
    _formChanges.removeListener(_formChanged);
    await _changes.close();
    await super.close();
  }
}
