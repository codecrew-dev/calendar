import 'package:calendar_app_flutter/logic/event_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz_data.initializeTimeZones();
  final la = tz.getLocation('America/Los_Angeles');
  final seoul = tz.getLocation('Asia/Seoul');

  test('Apple sample: Los Angeles start/end convert to next day in Korea', () {
    final start = wallTimeToDate('2026-09-09', '10:00', la);
    final end = wallTimeToDate('2026-09-09', '12:00', la);
    expect(start.toIso8601String(), '2026-09-09T17:00:00.000Z');
    final startInSeoul = zonedParts(start, seoul);
    expect(startInSeoul.date, '2026-09-10');
    expect(startInSeoul.time, '02:00');
    final endInSeoul = zonedParts(end, seoul);
    expect(endInSeoul.date, '2026-09-10');
    expect(endInSeoul.time, '04:00');
    expect(end.difference(start).inMinutes, 120);
    final startInLA = zonedParts(start, la);
    expect(startInLA.date, '2026-09-09');
    expect(startInLA.time, '10:00');
  });

  test('Winter timezone offset and DST gap', () {
    expect(wallTimeToDate('2026-01-09', '10:00', la).toIso8601String(), '2026-01-09T18:00:00.000Z');
    expect(() => wallTimeToDate('2026-03-08', '02:30', la), throwsFormatException);
  });

  test('Invalid dates and times rejected; midnight retained', () {
    expect(() => wallTimeToDate('2026-02-30', '10:00', seoul), throwsFormatException);
    expect(() => wallTimeToDate('2026-09-09', '25:00', seoul), throwsFormatException);
    final midnight = wallTimeToDate('2026-09-09', '00:00', seoul);
    final parts = zonedParts(midnight, seoul);
    expect(parts.date, '2026-09-09');
    expect(parts.time, '00:00');
  });

  test('Plain and pasted Markdown URLs; unsafe schemes rejected', () {
    const url = 'https://www.apple.com/kr/apple-events/';
    expect(normalizeEventURL('[$url]($url)'), url);
    expect(normalizeEventURL(' $url '), url);
    expect(normalizeEventURL(' '), '');
    expect(() => normalizeEventURL('javascript:alert(1)'), throwsFormatException);
    expect(() => normalizeEventURL('not a url'), throwsA(anything));
  });

  test('Moving start preserves duration across midnight and year boundaries', () {
    final original = DateTime.parse('2026-09-09T10:00:00Z');
    final end = DateTime.parse('2026-09-09T11:30:00Z');
    final next = DateTime.parse('2026-12-31T23:30:00Z');
    expect(shiftedEventEnd(original, end, next).toIso8601String(), '2027-01-01T01:00:00.000Z');
    expect(original.toIso8601String(), '2026-09-09T10:00:00.000Z');
  });

  test('Moving start repairs an end earlier than the start', () {
    final start = DateTime.parse('2026-09-09T10:00:00Z');
    expect(shiftedEventEnd(start, DateTime.parse('2026-09-09T09:00:00Z'), start).toIso8601String(), '2026-09-09T10:05:00.000Z');
  });
}
