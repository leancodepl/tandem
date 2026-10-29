import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
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
import 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/trip/trip_policy_breach_text.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_unknown_trip.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Expenses');

/// The expense report of a past trip. The agent fills it in from the trip's
/// receipts and asks to submit it; the request shows in the screen's own
/// bar, not in a chat.
@RoutePage()
final class const ExpensesReportPage({
  super.key,
  @PathParam() required final String tripId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (context
      .select<TripsCubit, Trip?>((trips) => trips.tripOrNull(tripId))) {
    final trip? => ChangeNotifierProvider(
      create: (context) {
        final reports = context.read<ReportsCubit>();
        return ExpensesReportFormController(
          receipts: reports.receipts(trip.id),
          stored: reports.report(trip.id),
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
            child: const _ExpensesReportContent(),
          ),
        ),
      ),
    ),
    null => const UnknownTrip(),
  };
}

final class const _ExpensesReportContent() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const WaypointPage(
    child: _ReceiptsForAgent(child: _ExpensesReportForm()),
  );
}

/// Tells the agent, when the report opens, about the receipts it does not
/// hold yet, and wakes it to add them.
final class const _ReceiptsForAgent({required final Widget child})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    useEffect(() {
      // Once the session is in scope: it starts with the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _tellAgent(context);
        }
      });
      return null;
    }, const []);

    return child;
  }

  static void _tellAgent(BuildContext context) {
    final cubit = context.read<ExpensesReportCubit>();
    final missing = [
      for (final receipt in cubit.receipts)
        if (!cubit.form.isClaimed(receipt.id)) receipt.id,
    ];
    if (cubit.state.submitted != null || missing.isEmpty) {
      return;
    }

    _log.fine('Told the agent of ${missing.length} receipts to add');
    TandemSessionScope.of(context)
      ..note(
        'The traveller forwarded receipts of the trip that are not in the '
        'report: ${missing.join(', ')}. Add them within the policy, then '
        'ask to submit the report.',
      )
      ..wake();
  }
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

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        WaypointTopBar(
          trailing: trip.purpose ?? l10n.clientWork,
          onBack: context.router.maybePop,
        ),
        Expanded(
          child: Readable(
            child: ListView(
              padding: const .fromLTRB(20, 0, 20, 24),
              keyboardDismissBehavior: .onDrag,
              children: [
                WaypointPageTitle(
                  trip.city.toUpperCase(),
                  below: l10n.reportDates(
                    l10n.dayRange(
                      trip.booked.outbound.departs,
                      trip.booked.homebound.departs,
                    ),
                  ),
                ),
                switch (session.failure) {
                  final failure? => InlineError(
                    l10n.agentFailure(failure),
                    onRetry: session.retry,
                  ),
                  null => WorkStatus(status, working: busy),
                },
                const SizedBox(height: 20),
                WaypointSection(
                  l10n.reportReceipts,
                  child: _Claims(enabled: !busy),
                ),
                const SizedBox(height: 18),
                WaypointNote(
                  Icons.verified_user_outlined,
                  l10n.companyPolicy(
                    l10n.expensesPolicy(l10n.euros(Policy.mealsPerDay)),
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

/// One claim for each receipt of the trip, which the traveller can change.
final class const _Claims({required final bool enabled})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final form = context.watch<ExpensesReportFormController>();
    final cubit = context.watch<ExpensesReportCubit>();
    final l10n = context.l10n;
    return WaypointGroup(
      children: [
        for (final (order, MapEntry(key: receipt, value: claim))
            in form.claims.entries.indexed)
          FormAmountField(
            field: claim,
            label: l10n.receiptLine(
              receipt.merchant,
              l10n.day(receipt.day),
              l10n.euros(receipt.paid),
            ),
            symbol: l10n.euroSymbol,
            enabled: enabled,
            marked: cubit.state.marked.contains(receipt.id),
            order: order,
            translateError: l10n.claimError,
            note: switch (int.tryParse(claim.fieldValue.trim())) {
              final claimed?
                  when claim.error == null &&
                      claimed > 0 &&
                      claimed < receipt.paid =>
                l10n.receiptNotPaidBack(l10n.euros(receipt.paid - claimed)),
              _ => null,
            },
            onEdited: () => cubit.unmark(receipt.id),
            textInputAction: order == form.claims.length - 1 ? .done : .next,
          ),
      ],
    );
  }
}

/// The total, and the way to submit: the agent's request to approve, the
/// traveller's own button, or the confirmation once submitted.
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
    final total = WaypointTotal(l10n.paidBack, l10n.euros(form.total));

    return WaypointActionBar(
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
              WaypointConfirmation(l10n.submitted, reference: confirmation),
            ],
          ),
          // The agent's request, in the screen's own bar.
          (final request?, _) => WaypointApproval(
            l10n.reportAskToSubmit(l10n.euros(form.total)),
            onApprove: () => _decide(() => session.approve(request)),
            onReject: () => _decide(() => session.reject(request)),
          ),
          _ => WaypointSubmit(
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
      // The report changed as the traveller tapped; the agent asks again.
      _log.warning('$error');
    }
  }
}

extension on AppLocalizations {
  String claimError(ClaimError error) => switch (error) {
    ClaimOutOfRange(:final paid) => claimOutOfRange(euros(paid)),
    ClaimOverPolicy(:final breach) => claimOverPolicy(policyBreach(breach)),
  };
}
