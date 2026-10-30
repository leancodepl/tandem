import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint_design_system/src/field_row.dart';
import 'package:waypoint_design_system/src/theme.dart';

/// A form field to write text in. [onEdited] runs on the traveller's input
/// only, never when the program writes the field. [maxLines] null lets the
/// text wrap onto as many lines as it needs.
final class const FormTextField<E extends Object>({
  super.key,
  required final AdvancedTextFieldController<E> field,
  required final String label,
  required final bool enabled,

  /// The assistant filled the field in. The mark grows a moment after the
  /// one of the field above, by [order].
  required final bool marked,
  required final int order,
  final ErrorTranslator<E>? translateError,
  final String? note,
  final VoidCallback? onEdited,
  final TextCapitalization textCapitalization = .none,
  final bool autocorrect = true,
  final TextInputAction textInputAction = .next,
  final int? maxLines = 1,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _TextRow(
    field: field,
    label: label,
    enabled: enabled,
    marked: marked,
    order: order,
    translateError: translateError,
    note: note,
    input: (enabled) => _Input(
      field: field,
      enabled: enabled,
      onEdited: onEdited,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      textInputAction: textInputAction,
      maxLines: maxLines,
    ),
  );
}

/// A form field for an amount in whole units of the currency [symbol].
final class const FormAmountField<E extends Object>({
  super.key,
  required final AdvancedTextFieldController<E> field,
  required final String label,
  required final String symbol,
  required final bool enabled,

  /// The assistant filled the field in. The mark grows a moment after the
  /// one of the field above, by [order].
  required final bool marked,
  required final int order,
  final ErrorTranslator<E>? translateError,
  final String? note,
  final VoidCallback? onEdited,
  final TextInputAction textInputAction = .next,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _TextRow(
    field: field,
    label: label,
    enabled: enabled,
    marked: marked,
    order: order,
    translateError: translateError,
    note: note,
    input: (enabled) => _Input(
      field: field,
      enabled: enabled,
      onEdited: onEdited,
      textInputAction: textInputAction,
      prefix: symbol,
      digitsOnly: true,
    ),
  );
}

/// A form field for a day between [first] and [last], picked from a
/// calendar that opens on the held day, or on [initial] while the field is
/// empty. [fromDay] turns the picked day into the value, such as the day at
/// a time of the field's own. With [withTime], a time picked after the day
/// replaces that time.
final class const FormDateField<E extends Object>({
  super.key,
  required final AdvancedFieldController<DateTime?, E> field,
  required final String label,
  required final String Function(DateTime value) format,
  required final DateTime first,
  required final DateTime last,
  final DateTime? initial,
  final DateTime Function(DateTime day)? fromDay,
  final bool withTime = false,
  required final bool enabled,

  /// The assistant filled the field in. The mark grows a moment after the
  /// one of the field above, by [order].
  required final bool marked,
  required final int order,
  final ErrorTranslator<E>? translateError,
  final String? note,
  final VoidCallback? onEdited,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _BoundRow(
    field: field,
    label: label,
    marked: marked,
    order: order,
    translateError: translateError,
    note: note,
    action: Icons.calendar_today_outlined,
    // No calendar when no day is left to pick.
    onTap: (state) =>
        enabled &&
            !state.readOnly &&
            !DateUtils.dateOnly(last).isBefore(DateUtils.dateOnly(first))
        ? () async {
            await _pick(context, state.value);
          }
        : null,
    input: (state) => _Value(switch (state.value) {
      final value? => format(value),
      null => null,
    }),
  );

  Future<void> _pick(BuildContext context, DateTime? held) async {
    final firstDay = DateUtils.dateOnly(first);
    final lastDay = DateUtils.dateOnly(last);
    final picked = await showDatePicker(
      context: context,
      initialDate: switch (held ?? initial) {
        null => firstDay,
        final shown when shown.isBefore(firstDay) => firstDay,
        final shown when shown.isAfter(lastDay) => lastDay,
        final shown => DateUtils.dateOnly(shown),
      },
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (picked == null || !context.mounted) return;

    var value = fromDay?.call(picked) ?? picked;
    if (withTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
        // The app shows its times on the 24-hour clock.
        builder: (context, picker) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: picker ?? const SizedBox.shrink(),
        ),
      );
      if (time == null || !context.mounted) return;
      value = DateTime(
        value.year,
        value.month,
        value.day,
        time.hour,
        time.minute,
      );
    }
    field.setValue(value);
    onEdited?.call();
  }
}

/// A form field that holds one of its field's options, all shown at once.
final class const FormSelectField<V, E extends Object>({
  super.key,
  required final AdvancedSingleSelectFieldController<V, E> field,
  required final String label,
  required final String Function(V option) optionLabel,
  required final bool enabled,

  /// The assistant filled the field in. The mark grows a moment after the
  /// one of the field above, by [order].
  required final bool marked,
  required final int order,
  final ErrorTranslator<E>? translateError,
  final VoidCallback? onEdited,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _BoundRow(
    field: field,
    label: label,
    marked: marked,
    order: order,
    translateError: translateError,
    note: null,
    input: (state) => Padding(
      padding: const .only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in field.options)
            _Chip(
              optionLabel(option),
              selected: option == state.value,
              onTap: enabled && !state.readOnly
                  ? () {
                      field.select(option);
                      onEdited?.call();
                    }
                  : null,
            ),
        ],
      ),
    ),
  );
}

/// A row whose input is a text field: a tap anywhere on it focuses the
/// input, and a tap outside every text row puts the keyboard away.
final class const _TextRow<E extends Object>({
  required final AdvancedTextFieldController<E> field,
  required final String label,
  required final bool enabled,
  required final bool marked,
  required final int order,
  required final ErrorTranslator<E>? translateError,
  required final String? note,
  required final Widget Function(bool enabled) input,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: _BoundRow(
      field: field,
      label: label,
      marked: marked,
      order: order,
      translateError: translateError,
      note: note,
      onTap: (state) =>
          enabled && !state.readOnly ? field.focusNode.requestFocus : null,
      action: Icons.edit_outlined,
      holdsInput: true,
      input: (state) => input(enabled && !state.readOnly),
    ),
  );
}

final class const _BoundRow<T, E extends Object>({
  required final AdvancedFieldController<T, E> field,
  required final String label,
  required final bool marked,
  required final int order,
  required final ErrorTranslator<E>? translateError,
  required final String? note,
  required final Widget Function(AdvancedFieldState<T, E> state) input,
  final VoidCallback? Function(AdvancedFieldState<T, E> state)? onTap,
  final IconData? action,
  final bool holdsInput = false,
}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final shownMarked = _useMarkedAfter(marked, order);
    return AdvancedFieldBuilder<T, E>(
      field: field,
      builder: (context, state, _) => FieldRow(
        label: label,
        marked: shownMarked,
        error: switch (state.error) {
          final error? => translateError?.call(error),
          null => null,
        },
        note: note,
        onTap: onTap?.call(state),
        action: action,
        holdsInput: holdsInput,
        child: input(state),
      ),
    );
  }
}

/// True 140 ms × [order] after [marked] turns true, so marks follow the
/// form down as FilledField's values do; false as soon as it turns false.
bool _useMarkedAfter(bool marked, int order) {
  final shown = useState(false);
  useEffect(() {
    if (!marked) {
      shown.value = false;
      return null;
    }
    final delay = Timer(
      Duration(milliseconds: 140 * order),
      () => shown.value = true,
    );
    return delay.cancel;
  }, [marked]);
  return shown.value;
}

final class const _Input({
  required final AdvancedTextFieldController<Object> field,
  required final bool enabled,
  required final VoidCallback? onEdited,
  required final TextInputAction textInputAction,
  final TextCapitalization textCapitalization = .none,
  final bool autocorrect = true,
  final int? maxLines = 1,
  final String? prefix,
  final bool digitsOnly = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextField(
    controller: field.textController,
    focusNode: field.focusNode,
    enabled: enabled,
    style: AppText.body,
    // Explicit, so that a field of many lines still moves on with Return.
    keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
    inputFormatters: digitsOnly
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    textCapitalization: textCapitalization,
    autocorrect: autocorrect,
    textInputAction: textInputAction,
    maxLines: maxLines,
    // iOS's number pad has no key to close it, and a touch outside a field
    // does not unfocus it on its own.
    onTapOutside: (_) => field.focusNode.unfocus(),
    // TextField reports only the traveller's input here, not a program write.
    onChanged: (_) => onEdited?.call(),
    decoration: InputDecoration(
      hintText: '—',
      hintStyle: AppText.body.copyWith(color: Palette.lineStrong),
      prefixText: prefix,
      prefixStyle: AppText.body,
      border: InputBorder.none,
      isDense: true,
      contentPadding: .zero,
    ),
  );
}

final class const _Value(final String? text) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    text ?? '—',
    style: AppText.body.copyWith(
      color: text == null ? Palette.lineStrong : Palette.ink,
    ),
  );
}

final class const _Chip(
  final String label, {
  required final bool selected,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? Palette.raised : Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? Palette.lineStrong : Palette.line),
        borderRadius: Radii.control,
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const .symmetric(horizontal: 12, vertical: 8),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: selected || onTap != null
                      ? Palette.ink
                      : Palette.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
