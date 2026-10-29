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
        AgentView.of(() => surface.selectedYear).as(
          'selected_year',
          'The year the invoice list shows. A request without a year means it.',
          .integer,
        ),
      ],
      calls: [
        AgentTool(
          surface.interpretInvoiceInput,
          name: 'interpret_invoice_input',
          description: 'Extract what a piece of user text actually expresses. Do not decide whether the app supports it. Preserve extra restrictions in the restriction field. This reports an interpretation and does not execute an archive: the app finds the matching invoices, and nothing changes until the user approves.',
          parameters: [
            AgentParameter<RequestedAction>(
              'action',
              .enumeration(
                [.archive, .search, .none],
                id: 'package:example/invoices/invoice_store.dart#RequestedAction',
              ),
              description: 'The requested action. Search phrases, find/show/select mean search. Negated or cancelled actions, past-tense statements and how-to questions mean none.',
            ),
            AgentParameter<RecordKind>(
              'recordKind',
              .enumeration([
                .invoice,
                .receipt,
                .other,
              ], id: 'package:example/invoices/invoice_store.dart#RecordKind'),
              description: 'The type of record explicitly named. Use invoice if omitted on this invoice screen.',
            ),
            AgentParameter<DateField>(
              'dateField',
              .enumeration([
                .issued,
                .paid,
                .due,
              ], id: 'package:example/invoices/invoice_store.dart#DateField'),
              description: 'Which date the text names: paid for a payment date, due for a due date, otherwise issued.',
            ),
            AgentParameter<Month>(
              'month',
              .enumeration([
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
              ], id: 'package:example/invoices/invoice_store.dart#Month'),
              description: 'The explicitly named month, otherwise unspecified. May in May I is not a month.',
            ),
            AgentParameter<int?>(
              'year',
              .nullable(.integer),
              description: 'The explicit year, or null if no year is supplied.',
              required: false,
            ),
            AgentParameter<Restriction>(
              'restriction',
              .enumeration([
                .none,
                .exclusion,
                .multipleMonths,
                .day,
                .vendor,
                .amount,
                .relativeDate,
                .other,
              ], id: 'package:example/invoices/invoice_store.dart#Restriction'),
              description: 'Any additional scope restriction: except/not a month, more than one month, a day, named vendor, amount, relative date, or other condition. Use none only when there is no extra condition.',
            ),
          ],
          invoke: (args) {
            surface.interpretInvoiceInput(
              action: args.read('action'),
              recordKind: args.read('recordKind'),
              dateField: args.read('dateField'),
              month: args.read('month'),
              year: args.read('year'),
              restriction: args.read('restriction'),
            );
            return null;
          },
        ),
      ],
    );
  }
}
