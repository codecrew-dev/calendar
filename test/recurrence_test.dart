import 'package:calendar_app_flutter/logic/recurrence.dart';
import 'package:calendar_app_flutter/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

CalendarEvent _base({EventRecurrence? recurrence, String? time = '10:00'}) => CalendarEvent(
      id: 'series',
      date: '2026-09-09',
      title: '회의',
      time: time,
      duration: 60,
      color: '#123456',
      recurrence: recurrence,
    );

void main() {
  tz_data.initializeTimeZones();
  final seoul = tz.getLocation('Asia/Seoul');

  test('Daily, weekly, biweekly repeats and inclusive end date', () {
    final cases = [
      (RepeatFrequency.daily, '2026-09-10', '2026-09-08'),
      (RepeatFrequency.weekly, '2026-09-16', '2026-09-15'),
      (RepeatFrequency.biweekly, '2026-09-23', '2026-09-16'),
    ];
    for (final (frequency, yes, no) in cases) {
      final event = _base(recurrence: EventRecurrence(frequency: frequency, until: yes));
      expect(occursOn(event, yes), true);
      expect(occursOn(event, no), false);
      expect(occursOn(event, '2027-09-09'), false);
    }
  });

  test('Monthly and yearly recurrence skip nonexistent dates', () {
    final monthly = _base().copyWith(date: '2026-01-31', recurrence: const EventRecurrence(frequency: RepeatFrequency.monthly));
    expect(occursOn(monthly, '2026-02-28'), false);
    expect(occursOn(monthly, '2026-03-31'), true);
    final yearly = _base().copyWith(date: '2024-02-29', recurrence: const EventRecurrence(frequency: RepeatFrequency.yearly));
    expect(occursOn(yearly, '2025-02-28'), false);
    expect(occursOn(yearly, '2028-02-29'), true);
  });

  test('Expansion preserves fields, unique IDs and series reference', () {
    final event = _base(recurrence: const EventRecurrence(frequency: RepeatFrequency.weekly));
    final source = {event.date: [event]};
    final result = expandEvents(source, '2026-09-01', '2026-09-30', seoul);
    expect(result['2026-09-09']!.length, 1);
    final occurrence = result['2026-09-16']![0];
    expect(occurrence.seriesId, event.id);
    expect(occurrence.id, isNot(event.id));
    expect(DateTime.parse(occurrence.endsAt!).difference(DateTime.parse(occurrence.startsAt!)).inMilliseconds, 3600000);
    expect(result['2026-10-07'], isNull);
    expect(expandEvents(source, '2030-09-01', '2030-09-30', seoul)['2030-09-11']![0].seriesId, event.id);
  });

  test('All-day repeats and no-repeat events remain correct', () {
    final event = _base(time: null, recurrence: const EventRecurrence(frequency: RepeatFrequency.daily, until: '2026-09-10'));
    final result = expandEvents({event.date: [event]}, '2026-09-09', '2026-09-12', seoul);
    expect(result['2026-09-10']![0].startsAt, isNull);
    expect(result['2026-09-11'], isNull);

    final plain = _base();
    final noRepeat = expandEvents({plain.date: [plain]}, '2026-09-01', '2026-09-30', seoul);
    expect(noRepeat.keys, [plain.date]);
    expect(noRepeat[plain.date]!.length, 1);
  });

  test('Invite emails are validated and deduplicated', () {
    expect(parseInvitees('A@example.com, b@example.com; a@example.com'), ['a@example.com', 'b@example.com']);
    expect(parseInvitees(''), <String>[]);
    expect(() => parseInvitees('invalid-email'), throwsFormatException);
  });

  test('Travel departure rolls into previous day', () {
    expect(departureLabel('2026-09-09', '00:15', 30, seoul), '2026-09-08 23:45 출발');
    expect(departureLabel('2026-09-09', '10:00', 30, seoul), '09:30 출발');
  });
}
