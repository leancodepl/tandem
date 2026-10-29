import 'package:auto_route/auto_route.dart';
import 'package:waypoint/navigation/app_router.dart';

// The tabs, and above them the pages they open. `plan-trip` comes before
// `:tripId`, which would match it too.
final routeTree = [
  AutoRoute(
    page: HomeRoute.page,
    path: '/',
    children: [
      AutoRoute(page: TripsRoute.page, path: 'trips', initial: true),
      AutoRoute(page: InboxRoute.page, path: 'inbox'),
      AutoRoute(page: ExpensesRoute.page, path: 'expenses'),
    ],
  ),
  AutoRoute(page: PlanTripRoute.page, path: '/trips/plan-trip'),
  AutoRoute(page: TripRoute.page, path: '/trips/:tripId'),
  AutoRoute(page: ArrivalRoute.page, path: '/trips/:tripId/arrival'),
  AutoRoute(page: ExpensesReportRoute.page, path: '/expenses/:tripId/report'),
];
