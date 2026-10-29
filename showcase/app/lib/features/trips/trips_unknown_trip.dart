import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

/// What a page of a trip shows for a trip that the traveller does not have,
/// such as from an old link.
final class const UnknownTrip({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ErrorView(
    context.l10n.unknownTrip,
    back: context.l10n.yourTrips,
    onBack: () => context.router.navigate(const TripsRoute()),
  );
}
