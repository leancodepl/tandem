// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_store.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$InvoiceStore implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as InvoiceStore;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.selectedYear,
          'selected_year',
          'The year the invoice list shows. A request without a year means it.',
          (selectedYear) => selectedYear,
        ),
      ],
      calls: [
        AgentTool(
          surface.interpretInvoiceInput,
          name: 'interpret_invoice_input',
          description: 'Extract what a piece of user text actually expresses. Do not decide whether the app supports it. Preserve extra restrictions in the restriction field. This reports an interpretation and does not execute an archive: the app finds the matching invoices, and nothing changes until the user approves.',
          parameters: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['archive', 'search', 'none'],
                'description': 'The requested action. Search phrases, find/show/select mean search. Negated or cancelled actions, past-tense statements and how-to questions mean none.',
              },
              'recordKind': {
                'type': 'string',
                'enum': ['invoice', 'receipt', 'other'],
                'description': 'The type of record explicitly named. Use invoice if omitted on this invoice screen.',
              },
              'dateField': {
                'type': 'string',
                'enum': ['issued', 'paid', 'due'],
                'description': 'Which date the text names: paid for a payment date, due for a due date, otherwise issued.',
              },
              'month': {
                'type': 'string',
                'enum': [
                  'january',
                  'february',
                  'march',
                  'april',
                  'may',
                  'june',
                  'july',
                  'august',
                  'september',
                  'october',
                  'november',
                  'december',
                  'unspecified',
                ],
                'description': 'The explicitly named month, otherwise unspecified. May in May I is not a month.',
              },
              'year': {
                'anyOf': [
                  {'type': 'integer'},
                  {'type': 'null'},
                ],
                'description':
                    'The explicit year, or null if no year is supplied.',
              },
              'restriction': {
                'type': 'string',
                'enum': [
                  'none',
                  'exclusion',
                  'multipleMonths',
                  'day',
                  'vendor',
                  'amount',
                  'relativeDate',
                  'other',
                ],
                'description': 'Any additional scope restriction: except/not a month, more than one month, a day, named vendor, amount, relative date, or other condition. Use none only when there is no extra condition.',
              },
            },
            'required': [
              'action',
              'recordKind',
              'dateField',
              'month',
              'restriction',
            ],
          },
          invoke: (args) {
            surface.interpretInvoiceInput(
              action: args.read('action', oneOf: [.archive, .search, .none]),
              recordKind: args.read(
                'recordKind',
                oneOf: [.invoice, .receipt, .other],
              ),
              dateField: args.read('dateField', oneOf: [.issued, .paid, .due]),
              month: args.read(
                'month',
                oneOf: [
                  .january,
                  .february,
                  .march,
                  .april,
                  .may,
                  .june,
                  .july,
                  .august,
                  .september,
                  .october,
                  .november,
                  .december,
                  .unspecified,
                ],
              ),
              year: args.read('year'),
              restriction: args.read(
                'restriction',
                oneOf: [
                  .none,
                  .exclusion,
                  .multipleMonths,
                  .day,
                  .vendor,
                  .amount,
                  .relativeDate,
                  .other,
                ],
              ),
            );
            return null;
          },
        ),
      ],
    );
  }
}
