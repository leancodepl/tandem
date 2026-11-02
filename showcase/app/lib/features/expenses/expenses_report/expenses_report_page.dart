import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/expenses/expenses_report/claim_error.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_state.dart';
import 'package:waypoint/features/expenses/expenses_report/receipt_claim_field.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/trip/trip_policy_breach_text.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_unknown_trip.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Expenses');

@RoutePage()
final class const ExpensesReportPage({
  super.key,
  @PathParam() required final String tripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (context.select<TripsCubit, Trip?>(
        (trips) => trips.tripOrNull(TripId.tryParse(tripId)),
      )) {
        final trip? => ChangeNotifierProvider(
          key: ValueKey(trip.id),
          create: (context) {
            final reports = context.read<ReportsCubit>();
            return ExpensesReportFormController(
              receipts: reports.receipts(trip.id),
              stored: reports.report(trip.id),
              inputs: reports.draftInputs(trip.id),
            );
          },
          child: BlocProvider(
            create: (context) => ExpensesReportCubit(
              trip: trip,
              reports: context.read<ReportsCubit>(),
              form: context.read<ExpensesReportFormController>(),
            ),
            child: Builder(
              builder: (context) => TandemScope.connected(
                surface: (context) => context.read<ExpensesReportCubit>(),
                connection: context.watch<Agents>().expenses,
                approvals: const .fromState(),
                onEvent: (context, event, session) => _log.agentEvent(event),
                child: const Scaffold(body: _ExpensesReportForm()),
              ),
            ),
          ),
        ),
        null => const UnknownTrip(),
      };
}

final class const _ExpensesReportForm() extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final form = context.watch<ExpensesReportFormController>();
    useListenable(form.onValuesChanged);
    final cubit = context.watch<ExpensesReportCubit>();
    final session = TandemSessionScope.of(context);
    final busy = session.status.isWorking;
    final said = _said(session.items);
    final l10n = context.l10n;
    final status = switch ((busy, form.lines)) {
      (true, _) => l10n.reportAdding,
      (_, []) => l10n.reportMissingReceipts,
      _ => said,
    };
    final trip = cubit.trip;
    final missing = [
      for (final receipt in form.receipts)
        if (!form.isClaimed(receipt.id)) receipt.id,
    ];
    final canAddReceipts =
        session.status is Idle &&
        cubit.state.submitted == null &&
        !cubit.state.submitting &&
        missing.isNotEmpty;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        WPTopBar(
          trailing: trip.purpose ?? l10n.clientWork,
          onBack: context.router.maybePop,
        ),
        Expanded(
          child: WPReadable(
            child: ListView(
              padding: const .fromLTRB(20, 0, 20, 24),
              keyboardDismissBehavior: .onDrag,
              children: [
                WPPageTitle(
                  trip.city.toUpperCase(),
                  below: l10n.reportDates(
                    l10n.dayRange(
                      trip.booked.outbound.departs,
                      trip.booked.homebound.departs,
                    ),
                  ),
                  trailing: WPButton(
                    l10n.reportAddReceiptsAction,
                    small: true,
                    onPressed: canAddReceipts
                        ? () => session.send(
                            'Add these forwarded receipts to my report within '
                            'the policy: '
                            '${missing.join(', ')}.',
                          )
                        : null,
                  ),
                ),
                switch (session.failure) {
                  final failure? => WPInlineError(
                    l10n.agentFailure(failure),
                    onRetry: session.retry,
                  ),
                  null => WPWorkStatus(status, working: busy),
                },
                const SizedBox(height: 20),
                WPSection(l10n.reportReceipts, child: _Claims(enabled: !busy)),
                const SizedBox(height: 18),
                WPNote(
                  Icons.verified_user_outlined,
                  l10n.companyPolicy(
                    l10n.expensesPolicy(l10n.money(Policy.mealsPerDay)),
                  ),
                ),
              ],
            ),
          ),
        ),
        _SubmitBar(busy: busy),
      ],
    );
  }

  /// What the agent said last, unless a request it made since went void:
  /// then it asks about a report the traveller has changed.
  static String? _said(List<ChatItem> items) {
    for (final item in items.reversed) {
      if (item case ApprovalRequest(status: .invalidated)) return null;
      if (item case AgentMessage(:final text)) {
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }
}

final class const _Claims({required final bool enabled})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final form = context.watch<ExpensesReportFormController>();
    final cubit = context.watch<ExpensesReportCubit>();
    final l10n = context.l10n;
    return WPGroup(
      children: [
        for (final (order, ReceiptClaimField(:receipt, field: claim))
            in form.claims.values.indexed)
          WPFormAmountField(
            field: claim,
            label: l10n.receiptLine(
              receipt.merchant,
              l10n.day(receipt.day),
              l10n.money(receipt.paid),
            ),
            symbol: l10n.currencySymbol(receipt.paid.currency),
            enabled: enabled,
            marked: cubit.state.marked.contains(receipt.id),
            order: order,
            translateError: l10n.claimError,
            note: switch (int.tryParse(claim.fieldValue.trim())) {
              final claimed?
                  when claim.error == null &&
                      claimed > 0 &&
                      claimed < receipt.paid.toInt() =>
                l10n.receiptNotPaidBack(
                  l10n.money(receipt.paid - wholeMoney(claimed)),
                ),
              _ => null,
            },
            onEdited: () => cubit.unmark(receipt.id),
            textInputAction: order == form.claims.length - 1 ? .done : .next,
          ),
      ],
    );
  }
}

final class const _SubmitBar({required final bool busy}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final form = context.watch<ExpensesReportFormController>();
    useListenable(form.onValuesChanged);
    final cubit = context.watch<ExpensesReportCubit>();
    final session = TandemSessionScope.of(context);
    final ExpensesReportState(:submitted, :submitting) = cubit.state;
    final request = session.items
        .whereType<ApprovalRequest>()
        .where((request) => request.status == .pending)
        .lastOrNull;
    final l10n = context.l10n;
    final total = WPTotal(l10n.paidBack, l10n.money(form.total));

    return WPActionBar(
      active: request != null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: .bottomCenter,
        child: switch ((request, submitted)) {
          (_, final confirmation?) => Row(
            spacing: 16,
            children: [
              Expanded(child: total),
              WPConfirmation(l10n.submitted, reference: confirmation.value),
            ],
          ),
          (final request?, _) => WPApproval(
            l10n.reportAskToSubmit(l10n.money(form.total)),
            onApprove: () => _decide(() => session.approve(request)),
            onReject: () => _decide(() => session.reject(request)),
          ),
          _ => WPSubmit(
            label: submitting ? l10n.submitting : l10n.submit,
            busy: submitting,
            total: total,
            onSubmit: cubit.ready && !busy
                ? () async {
                    await cubit.submit();
                  }
                : null,
          ),
        },
      ),
    );
  }

  void _decide(void Function() decision) {
    try {
      decision();
    } on ApprovalNotPending catch (error) {
      // The report changed as the traveller tapped.
      _log.warning('$error');
    }
  }
}

extension on AppLocalizations {
  String claimError(ClaimError error) => switch (error) {
    ClaimOutOfRange(:final paid) => claimOutOfRange(money(paid)),
    ClaimOverPolicy(:final breach) => claimOverPolicy(policyBreach(breach)),
  };
}
