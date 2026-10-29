import 'dart:async';

import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

/// What is changed on the screen and not booked, with the same Book button
/// the assistant's [TripCubit.bookChanges] stands for. Once booked, the
/// confirmation shows for a few seconds.
final class const ChangesBar({super.key, required final bool wide})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final booked = useState<TripPresentationEventChangesBooked?>(null);
    useEffect(() {
      if (booked.value == null) return null;

      final hide = Timer(const Duration(seconds: 5), () => booked.value = null);
      return hide.cancel;
    }, [booked.value]);

    return BlocPresentationListener<TripCubit, TripPresentationEvent>(
      listener: (context, event) => switch (event) {
        final TripPresentationEventChangesBooked changes =>
          booked.value = changes,
      },
      child: _ChangesBarContent(wide: wide, booked: booked.value),
    );
  }
}

final class const _ChangesBarContent({
  required final bool wide,
  required final TripPresentationEventChangesBooked? booked,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripCubit>();
    final booking = trip.state.booking;
    final status = TandemSessionScope.of(context).status;
    final awaiting = status is AwaitingApproval;
    final l10n = context.l10n;
    // On a phone the approval card shows the same, right below.
    final changes = !wide && awaiting
        ? const <BookingChange>[]
        : trip.bookingChanges;
    final confirmation = changes.isEmpty && !booking
        ? booked?.confirmation
        : null;

    final Widget? content = switch ((changes, booking, confirmation)) {
      ([_, ...], _, _) ||
      (_, true, _) when !(awaiting && !wide) => WaypointSubmit(
        key: const ValueKey('changes'),
        label: booking ? l10n.booking : l10n.bookChanges,
        busy: booking,
        total: WaypointTotal(
          l10n.changesNotBooked(changes.length),
          l10n.eurosDelta(trip.changesCost),
        ),
        onSubmit: status.isWorking || trip.changesBreach != null
            ? null
            : () {
                context.read<MarksCubit>().clear();
                trip.bookChanges();
              },
      ),
      (_, _, final confirmation?) => Align(
        key: const ValueKey('booked'),
        alignment: .centerLeft,
        child: WaypointConfirmation(l10n.changesBooked(confirmation)),
      ),
      _ => null,
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: .bottomCenter,
      child: switch (content) {
        // On a phone the assistant's dock is below the bar.
        final content? => WaypointActionBar(
          gutter: wide ? 36 : 20,
          bottom: wide,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: content,
          ),
        ),
        null => const SizedBox(width: double.infinity),
      },
    );
  }
}

extension EurosDelta on AppLocalizations {
  /// +€174, -€20
  String eurosDelta(int amount) {
    final euros = NumberFormat.simpleCurrency(
      locale: localeName,
      name: 'EUR',
      decimalDigits: 0,
    );
    return switch (amount) {
      >= 0 => '${euros.symbols.PLUS_SIGN}${euros.format(amount)}',
      _ => euros.format(amount),
    };
  }
}
