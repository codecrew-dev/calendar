import 'package:calendar_app_flutter/logic/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatLunarDate (ported korean-lunar-calendar data)', () {
    // Reference values captured from the original korean-lunar-calendar npm
    // package (see calendar_app/lib/date.ts), which this Dart port mirrors.
    final cases = <DateTime, String>{
      DateTime(2024, 2, 10): '음력 1. 1.',
      DateTime(2025, 1, 29): '음력 1. 1.',
      DateTime(2023, 6, 19): '음력 5. 2.',
      DateTime(2000, 1, 1): '음력 11. 25.',
      DateTime(2050, 12, 31): '음력 11. 18.',
    };

    cases.forEach((solar, expected) {
      test('$solar -> $expected', () {
        expect(formatLunarDate(solar), expected);
      });
    });
  });

  test('getMonthMatrix pads to full weeks and marks in-month days', () {
    // September 2026: month index 8 (0-indexed), starts on a Tuesday.
    final cells = getMonthMatrix(2026, 8);
    expect(cells.length % 7, 0);
    expect(cells.where((c) => c.inMonth).length, 30);
    expect(cells.first.date.weekday % 7, 0); // starts on Sunday
  });

  test('toDateKey / parseDateKey round-trip', () {
    final date = DateTime(2026, 9, 9);
    expect(toDateKey(date), '2026-09-09');
    final parsed = parseDateKey('2026-09-09');
    expect(isSameDay(parsed, date), true);
  });

  test('startOfWeek returns the preceding Sunday', () {
    final monday = DateTime(2026, 9, 7); // a Monday
    final start = startOfWeek(monday);
    expect(start.weekday % 7, 0);
    expect(toDateKey(start), '2026-09-06');
  });
}
