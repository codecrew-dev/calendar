import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_event.dart';
import 'event_details.dart';

const int _dayMs = 86400000;

DateTime _utcDate(String key) => DateTime.parse('${key}T00:00:00Z');
String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

bool occursOn(CalendarEvent event, String key) {
  final until = event.recurrence?.until;
  if (key.compareTo(event.date) < 0 || (until != null && key.compareTo(until) > 0)) return false;
  if (event.recurrence == null) return key == event.date;
  final start = _utcDate(event.date);
  final target = _utcDate(key);
  final days = ((target.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / _dayMs).round();
  switch (event.recurrence!.frequency) {
    case RepeatFrequency.daily:
      return true;
    case RepeatFrequency.weekly:
      return days % 7 == 0;
    case RepeatFrequency.biweekly:
      return days % 14 == 0;
    case RepeatFrequency.monthly:
      return start.day == target.day;
    case RepeatFrequency.yearly:
      return start.month == target.month && start.day == target.day;
  }
}

/// Expand only the visible [from, to] range; series are stored once, with no
/// finite repeat count. Ported from lib/recurrence.ts expandEvents.
EventMap expandEvents(EventMap events, String from, String to, tz.Location zone) {
  final result = <String, List<CalendarEvent>>{
    for (final entry in events.entries) entry.key: List<CalendarEvent>.from(entry.value),
  };
  final series = events.values.expand((list) => list).where((event) => event.recurrence != null).toList();

  final fromMs = _utcDate(from).millisecondsSinceEpoch;
  final toMs = _utcDate(to).millisecondsSinceEpoch;
  for (var stamp = fromMs; stamp <= toMs; stamp += _dayMs) {
    final key = _dateKey(DateTime.fromMillisecondsSinceEpoch(stamp, isUtc: true));
    for (final event in series) {
      if (key == event.date || !occursOn(event, key)) continue;
      String? startsAt, endsAt;
      if (event.time != null) {
        try {
          final start = wallTimeToDate(key, event.time!, zone);
          startsAt = start.toIso8601String();
          endsAt = start.add(Duration(minutes: event.duration)).toIso8601String();
        } catch (_) {
          continue; // Skip local clock times that do not exist at a DST transition.
        }
      }
      final occurrence = event.copyWith(
        id: '${event.id}::$key',
        seriesId: event.id,
        date: key,
        startsAt: startsAt,
        clearStartsAt: startsAt == null,
        endsAt: endsAt,
        clearEndsAt: endsAt == null,
      );
      (result[key] ??= []).add(occurrence);
    }
  }
  for (final list in result.values) {
    list.sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
  }
  return result;
}

String departureLabel(String date, String time, int minutes, tz.Location zone) {
  try {
    final start = wallTimeToDate(date, time, zone);
    final departure = zonedParts(start.subtract(Duration(minutes: minutes)), zone);
    final prefix = departure.date != date ? '${departure.date} ' : '';
    return '$prefix${departure.time} 출발';
  } catch (_) {
    return '';
  }
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

List<String> parseInvitees(String value) {
  final emails = <String>{
    for (final item in value.split(RegExp(r'[,;\s]+'))) if (item.trim().isNotEmpty) item.trim().toLowerCase(),
  }.toList();
  if (emails.any((email) => !_emailRe.hasMatch(email))) {
    throw const FormatException('초대할 사람의 이메일 주소를 확인해 주세요.');
  }
  return emails;
}
