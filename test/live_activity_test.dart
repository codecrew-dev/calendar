import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:calendar_app_flutter/models/calendar_event.dart';
import 'package:calendar_app_flutter/native/live_activity.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);
  CalendarEvent event(
    String id,
    String? time, {
    String date = '2026-09-15',
    int duration = 60,
    EventRecurrence? recurrence,
  }) => CalendarEvent(
    id: id,
    date: date,
    title: id,
    time: time,
    duration: duration,
    color: '#007aff',
    recurrence: recurrence,
  );

  test('only current timed events qualify; start inclusive, end exclusive', () {
    final events = {
      '2026-09-15': [
        event('current', '10:00'),
        event('ended', '09:00'),
        event('future', '11:00'),
        event('all-day', null),
      ],
    };
    final result = currentLiveEvents(
      events,
      tz.getLocation('Asia/Seoul'),
      DateTime.parse('2026-09-15T01:00:00Z'),
    );
    expect(result.map((e) => e.event.id), ['current']);
    expect(
      result.single.payload['start'],
      DateTime.parse('2026-09-15T01:00:00Z').millisecondsSinceEpoch / 1000,
    );
    expect(result.single.end, DateTime.parse('2026-09-15T02:00:00Z'));
  });

  test('recurrences and overnight events use the current occurrence', () {
    final events = {
      '2026-09-14': [
        event('overnight', '23:30', date: '2026-09-14', duration: 120),
      ],
      '2026-09-01': [
        event(
          'daily',
          '00:00',
          date: '2026-09-01',
          recurrence: const EventRecurrence(frequency: RepeatFrequency.daily),
        ),
      ],
    };
    final result = currentLiveEvents(
      events,
      tz.getLocation('Asia/Seoul'),
      DateTime.parse('2026-09-14T15:30:00Z'),
    );
    expect(result.map((e) => e.event.title).toSet(), {'overnight', 'daily'});
    expect(result.first.event.id, 'daily::2026-09-15');
  });

  test('changed times, deleted events, malformed input stop qualifying', () {
    final zone = tz.getLocation('Asia/Seoul');
    final now = DateTime.parse('2026-09-15T01:30:00Z');
    expect(
      currentLiveEvents(
        {
          '2026-09-15': [
            event('moved', '11:00'),
            event('invalid', 'xx'),
            event('zero', '10:00', duration: 0),
          ],
        },
        zone,
        now,
      ),
      isEmpty,
    );
    expect(currentLiveEvents({}, zone, now), isEmpty);
  });
}
