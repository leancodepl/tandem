import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:waypoint/features/arrival/arrival_page.dart';
import 'package:waypoint/features/expenses/expenses_list/expenses_list_page.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_page.dart';
import 'package:waypoint/features/home/home_page.dart';
import 'package:waypoint/features/inbox/inbox_page.dart';
import 'package:waypoint/features/plan_trip/plan_trip_page.dart';
import 'package:waypoint/features/trip/trip_page.dart';
import 'package:waypoint/features/trips/trips_page.dart';
import 'package:waypoint/navigation/route_tree.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
final class AppRouter() extends RootStackRouter {
  @override
  List<AutoRoute> get routes => routeTree;
}
