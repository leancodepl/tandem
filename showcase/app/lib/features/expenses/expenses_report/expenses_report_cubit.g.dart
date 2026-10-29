// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'expenses_report_cubit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ExpensesReportStateCWProxy {
  ExpensesReportState submitted(String? submitted);

  ExpensesReportState submitting(bool submitting);

  ExpensesReportState marked(Set<String> marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ExpensesReportState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ExpensesReportState(...).copyWith(id: 12, name: "My name")
  /// ```
  ExpensesReportState call({
    String? submitted,
    bool submitting,
    Set<String> marked,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfExpensesReportState.copyWith(...)` or call `instanceOfExpensesReportState.copyWith.fieldName(value)` for a single field.
class _$ExpensesReportStateCWProxyImpl implements _$ExpensesReportStateCWProxy {
  const _$ExpensesReportStateCWProxyImpl(this._value);

  final ExpensesReportState _value;

  @override
  ExpensesReportState submitted(String? submitted) =>
      call(submitted: submitted);

  @override
  ExpensesReportState submitting(bool submitting) =>
      call(submitting: submitting);

  @override
  ExpensesReportState marked(Set<String> marked) => call(marked: marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ExpensesReportState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ExpensesReportState(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ExpensesReportState call({
    Object? submitted = const $CopyWithPlaceholder(),
    Object? submitting = const $CopyWithPlaceholder(),
    Object? marked = const $CopyWithPlaceholder(),
  }) {
    return ExpensesReportState(
      submitted: submitted == const $CopyWithPlaceholder()
          ? _value.submitted
          // ignore: cast_nullable_to_non_nullable
          : submitted as String?,
      submitting:
          submitting == const $CopyWithPlaceholder() || submitting == null
          ? _value.submitting
          // ignore: cast_nullable_to_non_nullable
          : submitting as bool,
      marked: marked == const $CopyWithPlaceholder() || marked == null
          ? _value.marked
          // ignore: cast_nullable_to_non_nullable
          : marked as Set<String>,
    );
  }
}

extension $ExpensesReportStateCopyWith on ExpensesReportState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfExpensesReportState.copyWith(...)` or `instanceOfExpensesReportState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ExpensesReportStateCWProxy get copyWith =>
      _$ExpensesReportStateCWProxyImpl(this);
}

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ExpensesReportCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ExpensesReportCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.report).as(
          'report',
          'The report as the traveller sees it: every receipt of the trip and what of it is paid back.',
          .object(
            id: 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart#ReportSummary',
            fields: (field) => [
              field('trip', (value) => value.trip).as(.string),
              field('receipts', (value) => value.receipts).as(
                .list(
                  .object(
                    id: 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart#ReceiptSummary',
                    fields: (field) => [
                      field('id', (value) => value.id).as(.string),
                      field('merchant', (value) => value.merchant).as(.string),
                      field('category', (value) => value.category).as(
                        .enumeration(
                          [.taxi, .meal, .transport],
                          id: 'package:waypoint_travel/src/inbox.dart#ExpenseCategory',
                        ),
                      ),
                      field('day', (value) => value.day).as(.string),
                      field('paid', (value) => value.paid).as(.integer),
                      field(
                        'claimed',
                        (value) => value.claimed,
                        description: 'Paid back of it, or null while it is not in the report.',
                        required: false,
                      ).as(.nullable(.integer)),
                      field(
                        'problem',
                        (value) => value.problem,
                        description: 'Why the screen marks the claim as wrong, such as more than was paid, or null while it is right. The report cannot be submitted while a claim has a problem.',
                        required: false,
                      ).as(.nullable(.string)),
                    ],
                    build: (values) => .new(
                      id: values('id'),
                      merchant: values('merchant'),
                      category: values('category'),
                      day: values('day'),
                      paid: values('paid'),
                      claimed: values('claimed'),
                      problem: values('problem'),
                    ),
                  ),
                ),
              ),
              field(
                'total',
                (value) => value.total,
                description: 'Paid back in all, in euros.',
              ).as(.integer),
              field(
                'submitted',
                (value) => value.submitted,
                description: 'The confirmation once the report is submitted.',
                required: false,
              ).as(.nullable(.string)),
            ],
            build: (values) => .new(
              trip: values('trip'),
              receipts: values('receipts'),
              total: values('total'),
              submitted: values('submitted'),
            ),
          ),
        ),
        AgentView.of(() => surface.policy)
            .as('policy', "The company's rules for expenses.", .string),
      ],
      calls: [
        AgentTool(
          surface.addExpense,
          name: 'add_expense',
          description: 'Adds the receipt [receiptId] to the report, paying back [claimed] whole euros of it: what was paid, or less where the policy limits it.',
          parameters: [
            const AgentParameter<String>('receiptId', .string),
            const AgentParameter<int>('claimed', .integer),
          ],
          invoke: (args) {
            surface.addExpense(args.read('receiptId'), args.read('claimed'));
            return null;
          },
        ),
        AgentTool(
          surface.removeExpense,
          name: 'remove_expense',
          description: 'Takes the receipt [receiptId] out of the report.',
          parameters: [const AgentParameter<String>('receiptId', .string)],
          invoke: (args) {
            surface.removeExpense(args.read('receiptId'));
            return null;
          },
        ),
        AgentTool(
          surface.submitReport,
          name: 'submit_report',
          description: 'Submits the report exactly as it is on the screen, to be paid back. Returns its confirmation, to tell the traveller.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.submitReport();

            return AgentResult(result).as(
              .object(
                id: 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart#Submitted',
                description: 'What submit_report submitted.',
                fields: (field) => [
                  field(
                    'confirmation',
                    (value) => value.confirmation,
                  ).as(.string),
                  field('total', (value) => value.total).as(.integer),
                ],
                build: (values) => .new(
                  confirmation: values('confirmation'),
                  total: values('total'),
                ),
              ),
            );
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on ExpensesReportCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('report', report),
    .seesAs('policy', policy),
    if (_open) ...[.calls(addExpense), .calls(removeExpense)],
    if (ready) .callsWithApproval(submitReport),
  ];
}
