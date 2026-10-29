import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_reasks_cubit.dart';

final _log = Logger('Trip');

/// What the app notes for the agent when the traveller's change voided its
/// approval.
const _reask =
    'The traveller changed the trip on the screen after you asked to book. '
    'Ask again for the trip as it is now.';

/// Asks the agent again, on its own, when the traveller's change voided its
/// approval: once the trip has been still for a moment, so the traveller can
/// finish what they are changing.
final class const Reasker({super.key, required final Widget child})
    extends HookWidget {
  static const _settle = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final trip = context.watch<TripCubit>().state;
    final reasks = context.watch<ReasksCubit>();
    final last = session.items.whereType<ApprovalRequest>().lastOrNull;
    final voided = switch (last) {
      final request? when request.status == .invalidated =>
        reasks.state.contains(request) ? null : request,
      _ => null,
    };

    useEffect(() {
      if (voided == null) return null;

      final timer = Timer(_settle, () {
        if (session.status is Idle) {
          _log.info('Asked the agent again for ${voided.tool}');
          reasks.add(voided);
          session
            ..note(_reask)
            ..wake();
        }
      });
      return timer.cancel;
    }, [voided, trip, session.status, session.items.length]);

    return child;
  }
}
