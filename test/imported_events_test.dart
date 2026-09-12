import 'package:calendar_app_flutter/models/calendar_event.dart';
import 'package:calendar_app_flutter/storage/imported_events.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(String id, String date) => CalendarEvent(
  id: id,
  date: date,
  title: id,
  duration: 60,
  color: '#707078',
);

void main() {
  test('refreshing a provider retains the other imported calendars', () {
    final events = ImportedEvents();
    events.replaceProvider('google', {
      '2026-09-01': [event('import:google:a', '2026-09-01')],
    });
    events.replaceProvider('kakao', {
      '2026-09-02': [event('import:kakao:a', '2026-09-02')],
    });
    events.replaceProvider('google', {
      '2026-09-03': [event('import:google:b', '2026-09-03')],
    });
    expect(events.events.keys, containsAll(['2026-09-02', '2026-09-03']));
    expect(events.events.keys, isNot(contains('2026-09-01')));
  });
}
