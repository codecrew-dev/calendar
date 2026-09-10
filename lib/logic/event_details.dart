import 'package:timezone/timezone.dart' as tz;

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

class ZonedParts {
  final String date;
  final String time;
  const ZonedParts(this.date, this.time);
}

String _pad2(int n) => n.toString().padLeft(2, '0');

ZonedParts zonedParts(DateTime instant, tz.Location zone) {
  final local = tz.TZDateTime.from(instant, zone);
  final date = '${local.year.toString().padLeft(4, '0')}-${_pad2(local.month)}-${_pad2(local.day)}';
  final time = '${_pad2(local.hour)}:${_pad2(local.minute)}';
  return ZonedParts(date, time);
}

/// DST-safe wall-clock -> instant conversion, ported from lib/eventDetails.ts
/// wallTimeToDate. Throws a [FormatException] for input that doesn't exist in
/// the given zone (a wall-clock time skipped by a DST transition).
DateTime wallTimeToDate(String date, String time, tz.Location zone) {
  if (!_dateRe.hasMatch(date) || !_timeRe.hasMatch(time)) {
    throw const FormatException('날짜와 시간을 확인해 주세요.');
  }
  final target = DateTime.utc(
    int.parse(date.substring(0, 4)),
    int.parse(date.substring(5, 7)),
    int.parse(date.substring(8, 10)),
    int.parse(time.substring(0, 2)),
    int.parse(time.substring(3, 5)),
  );
  // DateTime.utc silently normalizes an out-of-range day/month (e.g. Feb 30
  // rolls to Mar 2) instead of throwing; catch that the way the JS original does.
  if (target.toIso8601String().substring(0, 10) != date) {
    throw const FormatException('날짜와 시간을 확인해 주세요.');
  }
  final targetMs = target.millisecondsSinceEpoch;
  var instantMs = targetMs;
  for (var i = 0; i < 4; i++) {
    final shown = zonedParts(DateTime.fromMillisecondsSinceEpoch(instantMs, isUtc: true), zone);
    final shownUtcMs = DateTime.utc(
      int.parse(shown.date.substring(0, 4)),
      int.parse(shown.date.substring(5, 7)),
      int.parse(shown.date.substring(8, 10)),
      int.parse(shown.time.substring(0, 2)),
      int.parse(shown.time.substring(3, 5)),
    ).millisecondsSinceEpoch;
    final offset = shownUtcMs - targetMs;
    if (offset == 0) return DateTime.fromMillisecondsSinceEpoch(instantMs, isUtc: true);
    instantMs -= offset;
  }
  throw const FormatException('해당 시간대에 존재하지 않는 시간입니다. 날짜와 시간을 확인해 주세요.');
}

String normalizeEventURL(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final markdown = RegExp(r'^\[[^\]]*\]\((https?:\/\/[^\s]+)\)$').firstMatch(trimmed);
  final uri = Uri.parse(markdown != null ? markdown.group(1)! : trimmed);
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const FormatException('http 또는 https 링크를 입력해 주세요.');
  }
  return uri.toString();
}

DateTime shiftedEventEnd(DateTime previousStart, DateTime previousEnd, DateTime nextStart) {
  final durationMs = (previousEnd.difference(previousStart).inMilliseconds).clamp(5 * 60000, 1 << 62);
  return nextStart.add(Duration(milliseconds: durationMs));
}
