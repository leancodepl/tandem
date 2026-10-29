// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [ArrivalPage]
class ArrivalRoute extends PageRouteInfo<ArrivalRouteArgs> {
  ArrivalRoute({
    Key? key,
    required String tripId,
    List<PageRouteInfo>? children,
  }) : super(
         ArrivalRoute.name,
         args: ArrivalRouteArgs(key: key, tripId: tripId),
         rawPathParams: {'tripId': tripId},
         initialChildren: children,
       );

  static const String name = 'ArrivalRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ArrivalRouteArgs>(
        orElse: () => ArrivalRouteArgs(tripId: pathParams.getString('tripId')),
      );
      return ArrivalPage(key: args.key, tripId: args.tripId);
    },
  );
}

class ArrivalRouteArgs {
  const ArrivalRouteArgs({this.key, required this.tripId});

  final Key? key;

  final String tripId;

  @override
  String toString() {
    return 'ArrivalRouteArgs{key: $key, tripId: $tripId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArrivalRouteArgs) return false;
    return key == other.key && tripId == other.tripId;
  }

  @override
  int get hashCode => key.hashCode ^ tripId.hashCode;
}

/// generated route for
/// [ExpensesListPage]
class ExpensesRoute extends PageRouteInfo<void> {
  const ExpensesRoute({List<PageRouteInfo>? children})
    : super(ExpensesRoute.name, initialChildren: children);

  static const String name = 'ExpensesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ExpensesListPage();
    },
  );
}

/// generated route for
/// [ExpensesReportPage]
class ExpensesReportRoute extends PageRouteInfo<ExpensesReportRouteArgs> {
  ExpensesReportRoute({
    Key? key,
    required String tripId,
    List<PageRouteInfo>? children,
  }) : super(
         ExpensesReportRoute.name,
         args: ExpensesReportRouteArgs(key: key, tripId: tripId),
         rawPathParams: {'tripId': tripId},
         initialChildren: children,
       );

  static const String name = 'ExpensesReportRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ExpensesReportRouteArgs>(
        orElse: () =>
            ExpensesReportRouteArgs(tripId: pathParams.getString('tripId')),
      );
      return ExpensesReportPage(key: args.key, tripId: args.tripId);
    },
  );
}

class ExpensesReportRouteArgs {
  const ExpensesReportRouteArgs({this.key, required this.tripId});

  final Key? key;

  final String tripId;

  @override
  String toString() {
    return 'ExpensesReportRouteArgs{key: $key, tripId: $tripId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExpensesReportRouteArgs) return false;
    return key == other.key && tripId == other.tripId;
  }

  @override
  int get hashCode => key.hashCode ^ tripId.hashCode;
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomePage();
    },
  );
}

/// generated route for
/// [InboxPage]
class InboxRoute extends PageRouteInfo<void> {
  const InboxRoute({List<PageRouteInfo>? children})
    : super(InboxRoute.name, initialChildren: children);

  static const String name = 'InboxRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const InboxPage();
    },
  );
}

/// generated route for
/// [PlanTripPage]
class PlanTripRoute extends PageRouteInfo<PlanTripRouteArgs> {
  PlanTripRoute({
    Key? key,
    String? invitationTripId,
    List<PageRouteInfo>? children,
  }) : super(
         PlanTripRoute.name,
         args: PlanTripRouteArgs(key: key, invitationTripId: invitationTripId),
         rawQueryParams: {'invitation': invitationTripId},
         initialChildren: children,
       );

  static const String name = 'PlanTripRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<PlanTripRouteArgs>(
        orElse: () => PlanTripRouteArgs(
          invitationTripId: queryParams.optString('invitation'),
        ),
      );
      return PlanTripPage(
        key: args.key,
        invitationTripId: args.invitationTripId,
      );
    },
  );
}

class PlanTripRouteArgs {
  const PlanTripRouteArgs({this.key, this.invitationTripId});

  final Key? key;

  final String? invitationTripId;

  @override
  String toString() {
    return 'PlanTripRouteArgs{key: $key, invitationTripId: $invitationTripId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlanTripRouteArgs) return false;
    return key == other.key && invitationTripId == other.invitationTripId;
  }

  @override
  int get hashCode => key.hashCode ^ invitationTripId.hashCode;
}

/// generated route for
/// [TripPage]
class TripRoute extends PageRouteInfo<TripRouteArgs> {
  TripRoute({Key? key, required String tripId, List<PageRouteInfo>? children})
    : super(
        TripRoute.name,
        args: TripRouteArgs(key: key, tripId: tripId),
        rawPathParams: {'tripId': tripId},
        initialChildren: children,
      );

  static const String name = 'TripRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TripRouteArgs>(
        orElse: () => TripRouteArgs(tripId: pathParams.getString('tripId')),
      );
      return TripPage(key: args.key, tripId: args.tripId);
    },
  );
}

class TripRouteArgs {
  const TripRouteArgs({this.key, required this.tripId});

  final Key? key;

  final String tripId;

  @override
  String toString() {
    return 'TripRouteArgs{key: $key, tripId: $tripId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TripRouteArgs) return false;
    return key == other.key && tripId == other.tripId;
  }

  @override
  int get hashCode => key.hashCode ^ tripId.hashCode;
}

/// generated route for
/// [TripsPage]
class TripsRoute extends PageRouteInfo<void> {
  const TripsRoute({List<PageRouteInfo>? children})
    : super(TripsRoute.name, initialChildren: children);

  static const String name = 'TripsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TripsPage();
    },
  );
}
