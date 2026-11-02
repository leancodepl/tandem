import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/inbox/inbox_page.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  testWidgets('inbox notes and actions fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const inbox = Inbox();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: inbox),
          RepositoryProvider(create: (context) => demoTraveller()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => TripsCubit(demoTrips(), inbox: inbox),
            ),
            BlocProvider(create: (context) => ReportsCubit(inbox: inbox)),
          ],
          child: MaterialApp(
            theme: wpTheme(),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              WPLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: InboxPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mira Novak, Alpenlicht'), findsOneWidget);
    expect(find.text('Plan the trip'), findsOneWidget);
  });
}
