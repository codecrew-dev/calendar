import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_app_flutter/screens/month_agenda.dart';
import 'package:calendar_app_flutter/screens/time_grid_view.dart';
import 'package:calendar_app_flutter/theme/app_theme.dart';
import 'package:calendar_app_flutter/widgets/top_bar.dart';

void main() {
  testWidgets('month navigation opens and invokes callbacks', (tester) async {
    var previous = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBar(
            theme: lightTheme,
            title: '2026. 9.',
            onPrev: () => previous++,
            onNext: () {},
            onToday: () {},
            onMenu: () {},
            onSearch: () {},
          ),
        ),
      ),
    );
    expect(find.text('오늘'), findsNothing);
    await tester.tap(find.textContaining('2026. 9.'));
    await tester.pump();
    await tester.tap(find.byTooltip('이전 기간'));
    expect(previous, 1);
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets(
      'agenda opens, switches and collapses on a small screen (${theme.isDark})',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildMaterialTheme(theme),
            home: Scaffold(
              body: MonthAgenda(
                theme: theme,
                viewDate: DateTime(2026, 9),
                events: const {},
                selectedKey: '2026-09-10',
                onSelectDate: (_) {},
                onEventPress: (_) {},
                onSlotPress: (_, _) {},
              ),
            ),
          ),
        );
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();
        expect(find.text('일정이 없습니다'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('시간표'));
        await tester.pumpAndSettle();
        expect(find.byType(TimeGridView), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.bySemanticsLabel('일정 목록 접기'));
        await tester.pumpAndSettle();
        expect(find.byType(TimeGridView), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
