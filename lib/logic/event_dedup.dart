import '../models/calendar_event.dart';
import 'date_utils.dart' as dates;

String _titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

bool _sameOrSimilarTitle(CalendarEvent left, CalendarEvent right) {
  final a = _titleKey(left.title);
  final b = _titleKey(right.title);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  // A provider often appends a source or a short location to the same event.
  return a.length >= 3 && b.length >= 3 && (a.contains(b) || b.contains(a));
}

bool _sameTime(CalendarEvent left, CalendarEvent right) {
  if (left.time == null || right.time == null) return left.time == right.time;
  final startDifference =
      (dates.minutesFromTime(left.time!) - dates.minutesFromTime(right.time!))
          .abs();
  final durationDifference = (left.duration - right.duration).abs();
  return startDifference <= 5 && durationDifference <= 15;
}

/// Keeps local events first, then one representative of matching imported
/// events. Events at different times are always kept, even with the same name.
EventMap mergeAndDeduplicateEvents(EventMap local, EventMap imported) {
  final result = <String, List<CalendarEvent>>{};
  final dates = {...local.keys, ...imported.keys};
  for (final date in dates) {
    final kept = <CalendarEvent>[...local[date] ?? const []];
    for (final event in imported[date] ?? const []) {
      final duplicate = kept.any(
        (other) => _sameTime(other, event) && _sameOrSimilarTitle(other, event),
      );
      if (!duplicate) kept.add(event);
    }
    kept.sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
    if (kept.isNotEmpty) result[date] = kept;
  }
  return result;
}

/// Public holidays, solar terms, and statutory anniversaries are supplied by
/// the special-day service. Hide an imported copy on the same date so a
/// subscribed holiday calendar does not render the label twice.
EventMap removeSpecialDayDuplicates(
  EventMap imported,
  Map<String, String> holidays,
  Map<String, String> solarTerms,
  Map<String, List<String>> anniversaries,
) {
  final result = <String, List<CalendarEvent>>{};
  for (final entry in imported.entries) {
    final names = <String>{
      if (holidays[entry.key] case final String name) name,
      if (solarTerms[entry.key] case final String name) name,
      ...?anniversaries[entry.key],
    }.map(_titleKey).where((name) => name.isNotEmpty).toList();
    result[entry.key] = entry.value.where((event) {
      final title = _titleKey(event.title);
      return !names.any(
        (name) =>
            title == name ||
            (title.length >= 2 &&
                name.length >= 2 &&
                (title.contains(name) || name.contains(title))),
      );
    }).toList();
  }
  return result;
}
