import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity_cubit.dart';
import 'package:waypoint/features/trip/trip_approval_card.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

/// The assistant beside the trip on an iPad or a Mac.
final class const AssistantPanel({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Palette.panel,
    child: SafeArea(
      left: false,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          _Header(height: 60),
          Expanded(child: _Thread()),
          Padding(padding: .fromLTRB(16, 8, 16, 16), child: _TripComposer()),
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
        color: Palette.panel,
        borderRadius: BorderRadius.vertical(top: Radii.sheet),
        border: Border(top: BorderSide(color: Palette.lineStrong)),
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
                          _Header(height: 44),
                          Flexible(child: _Thread(shrinkWrap: true)),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const Padding(
              padding: .fromLTRB(12, 10, 12, 8),
              child: _TripComposer(),
            ),
          ],
        ),
      ),
    );
  }
}

final class const _Header({required final double height})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = TandemSessionScope.of(context).status;
    // The agent at work shows in the thread, where its answer comes; the
    // header says only when it waits for the traveller.
    final waiting = status is AwaitingApproval;
    final l10n = context.l10n;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const .symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.assistant, style: AppText.title)),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: waiting ? 1 : 0,
                    child: Row(
                      spacing: 6,
                      children: [
                        const WaypointDot(),
                        Text(
                          l10n.waitingForYou,
                          style: AppText.label.copyWith(color: Palette.aiText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const WaypointDivider(),
        ],
      ),
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
      nights,
    ),
    FlightsLookedUpStep(:final origin?, :final destination?, :final date?) =>
      stepFlightsOn(origin, destination, day(date)),
    FlightsLookedUpStep() => stepFlights,
    FlightHomeStep(:final number, :final departs) => stepFlightHome(
      number,
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
          child: Text(context.l10n.assistantEmpty, style: AppText.label),
        ),
      );
    }
    final steps = context.watch<ActivityCubit>().state.steps;
    // A call the traveller approved shows as its busy button instead.
    final working = session.status.isStoppable;
    final retry = session.failure == null ? null : session.retry;
    // The items with the agent's steps after the item each followed, and the
    // agent at work last, where its answer will show.
    final entries = <Widget>[
      for (final (index, item) in items.indexed) ...[
        // A wake-up of the app is for the agent, not the traveller.
        if (item case UserMessage(fromApp: true))
          const SizedBox.shrink()
        else
          switch (item) {
            UserMessage(:final text) => WaypointBubble(text),
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
              key: ValueKey((session, request.toolCallId)),
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

/// One thing the agent did to the trip.
final class const _Step(final AgentStep step) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SlideIn(
    child: WaypointNote(
      Icons.check_rounded,
      context.l10n.step(step),
      tone: .done,
    ),
  );
}

/// The agent at work, at the end of the thread.
final class const _Working() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SlideIn(
    child: WorkStatus(
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
      Text(text, style: AppText.body),
      if (stopped) Text(context.l10n.stopped, style: AppText.label),
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
      final failure? => InlineError(
        l10n.agentFailure(failure),
        onRetry: onRetry,
      ),
      null => Text(
        kind == .stopped ? l10n.noticeStopped : l10n.noticeStartedOver,
        style: AppText.label,
      ),
    };
  }
}

/// The composer, bound to the trip's session.
final class const _TripComposer() extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final text = useTextEditingController();
    final session = TandemSessionScope.of(context);
    final status = session.status;
    return WaypointComposer(
      controller: text,
      hint: context.l10n.tripComposerHint,
      working: status.isRunning,
      onSend: () {
        session.send(text.text);
        text.clear();
        // On a phone the keyboard would hide the trip the assistant changes.
        FocusScope.of(context).unfocus();
      },
      onStop: status.isStoppable ? session.stop : null,
    );
  }
}
