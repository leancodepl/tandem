import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_composer.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity.dart';
import 'package:waypoint/features/trip/trip_activity_cubit.dart';
import 'package:waypoint/features/trip/trip_approval_card.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

final class const AssistantPanel({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: WPColors.panel,
    child: SafeArea(
      left: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const _Header(minHeight: 60),
          const Expanded(child: _Thread()),
          Padding(
            padding: const .fromLTRB(16, 8, 16, 16),
            child: SessionComposer(hint: context.l10n.tripComposerHint),
          ),
        ],
      ),
    ),
  );
}

/// The assistant under the trip on a phone: the last messages above the
/// field, so the trip stays in view while the assistant works on it.
final class const AssistantDock({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final talking = session.items.isNotEmpty;
    final screen = MediaQuery.sizeOf(context).height;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WPColors.panel,
        borderRadius: BorderRadius.vertical(top: WPRadii.sheet),
        border: Border(top: BorderSide(color: WPColors.lineStrong)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: .bottomCenter,
              child: talking
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: screen * .40),
                      child: const Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .stretch,
                        children: [
                          _Header(minHeight: 44),
                          Flexible(child: _Thread(shrinkWrap: true)),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const .fromLTRB(12, 10, 12, 8),
              child: SessionComposer(hint: context.l10n.tripComposerHint),
            ),
          ],
        ),
      ),
    );
  }
}

final class const _Header({required final double minHeight})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = TandemSessionScope.of(context).status;
    // The agent at work shows in the thread, where its answer comes; the
    // header says only when it waits for the traveller.
    final waiting = status is AwaitingApproval;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: .min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const .symmetric(horizontal: 20, vertical: 10),
            child: Align(
              heightFactor: 1,
              child: OverflowBar(
                alignment: .spaceBetween,
                spacing: 12,
                overflowSpacing: 8,
                children: [
                  Text(l10n.assistant, style: WPTextStyle.title),
                  if (waiting)
                    Row(
                      mainAxisSize: .min,
                      spacing: 6,
                      children: [
                        const WPDot(),
                        Flexible(
                          child: Text(
                            l10n.waitingForYou,
                            style: WPTextStyle.label.copyWith(
                              color: WPColors.aiText,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const WPDivider(),
      ],
    );
  }
}

extension on AppLocalizations {
  String status(SessionStatus status) => switch (status) {
    Idle() || Thinking() => statusThinking,
    Calling(:final tool) => switch (TripAction.of(tool)) {
      FindFlights() => statusFindingFlights,
      MoveMeeting() => statusMovingMeeting,
      SetHomeboundFlight() => statusChangingFlightHome,
      SetHotelNights() => statusChangingHotel,
      BookChanges() => booking,
      null => statusWorking,
    },
    AwaitingApproval() => waitingForYou,
    Stopping() => statusStopping,
  };

  String step(AgentStep step) => switch (step) {
    MeetingMovedStep(:final meeting, :final start) => stepMeetingMoved(
      meeting.toLowerCase(),
      dayTime(start),
    ),
    HotelNightsStep(:final hotel, :final nights) => stepHotelNights(
      hotel,
      nights.value,
    ),
    FlightsLookedUpStep(:final origin?, :final destination?, :final date?) =>
      stepFlightsOn(origin.value, destination.value, day(date)),
    FlightsLookedUpStep() => stepFlights,
    FlightHomeStep(:final number, :final departs) => stepFlightHome(
      number.value,
      dayTime(departs),
    ),
  };
}

final class const _Thread({final bool shrinkWrap = false})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final items = session.items;
    if (items.isEmpty) {
      return Padding(
        padding: const .all(20),
        child: Align(
          alignment: .bottomLeft,
          child: Text(context.l10n.assistantEmpty, style: WPTextStyle.label),
        ),
      );
    }
    final steps = context.watch<ActivityCubit>().state.steps;
    // A call the traveller approved shows as its busy button instead.
    final working = session.status.isStoppable;
    final retry = session.failure == null ? null : session.retry;
    final entries = <Widget>[
      for (final (index, item) in items.indexed) ...[
        switch (item) {
          UserMessage(:final text) => WPBubble(text),
          AgentMessage(:final text, :final stopped) => _AgentText(
            text,
            stopped: stopped,
          ),
          ChatNotice(:final kind) => _Notice(
            kind,
            onRetry: index == items.length - 1 ? retry : null,
          ),
          // A card of another call at the same index gets a new state.
          final ApprovalRequest request => ApprovalCard(
            request,
            key: ValueKey((session, request.key)),
          ),
        },
        for (final step in steps)
          if (step.after == index + 1) _Step(step),
      ],
      if (working) const _Working(),
    ];
    // Reversed, so that the newest item stays in view.
    return ListView.builder(
      reverse: true,
      shrinkWrap: shrinkWrap,
      padding: const .fromLTRB(20, 14, 20, 10),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return switch (entry) {
          SizedBox() => entry,
          _Step() => Padding(padding: const .only(bottom: 8), child: entry),
          _ => Padding(padding: const .only(bottom: 12), child: entry),
        };
      },
    );
  }
}

final class const _Step(final AgentStep step) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPSlideIn(
    child: WPNote(Icons.check_rounded, context.l10n.step(step), tone: .done),
  );
}

final class const _Working() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPSlideIn(
    child: WPWorkStatus(
      context.l10n.status(TandemSessionScope.of(context).status),
      working: true,
    ),
  );
}

final class const _AgentText(final String text, {final bool stopped = false})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 4,
    children: [
      Text(text, style: WPTextStyle.body),
      if (stopped) Text(context.l10n.stopped, style: WPTextStyle.label),
    ],
  );
}

final class const _Notice(
  final ChatNoticeKind kind, {
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (AgentFailure.of(kind)) {
      final failure? => WPInlineError(
        l10n.agentFailure(failure),
        onRetry: onRetry,
      ),
      null => Text(
        kind == .stopped ? l10n.noticeStopped : l10n.noticeStartedOver,
        style: WPTextStyle.label,
      ),
    };
  }
}
