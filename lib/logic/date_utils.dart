import 'korean_lunar_calendar.dart';

const List<String> weekdays = ['일', '월', '화', '수', '목', '금', '토'];
final List<int> hoursOfDay = List.generate(24, (i) => i);

String toDateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addDays(DateTime date, int n) => DateTime(date.year, date.month, date.day + n, date.hour, date.minute, date.second);

DateTime addMonths(DateTime date, int n) => DateTime(date.year, date.month + n, 1);

DateTime startOfWeek(DateTime date) => addDays(date, -(date.weekday % 7));

List<DateTime> getWeekDays(DateTime date) {
  final start = startOfWeek(date);
  return List.generate(7, (i) => addDays(start, i));
}

class MonthCell {
  final DateTime date;
  final bool inMonth;
  const MonthCell(this.date, this.inMonth);
}

/// `month` is 0-indexed, matching the original lib/date.ts (JS Date month convention).
List<MonthCell> getMonthMatrix(int year, int month) {
  final firstOfMonth = DateTime(year, month + 1, 1);
  final startOffset = firstOfMonth.weekday % 7; // JS getDay(): Sun=0..Sat=6
  final daysInMonth = DateTime(year, month + 2, 0).day;
  final daysInPrevMonth = DateTime(year, month + 1, 0).day;

  final cells = <MonthCell>[];
  for (var i = startOffset - 1; i >= 0; i--) {
    cells.add(MonthCell(DateTime(year, month, daysInPrevMonth - i), false));
  }
  for (var day = 1; day <= daysInMonth; day++) {
    cells.add(MonthCell(DateTime(year, month + 1, day), true));
  }
  final remainder = (7 - (cells.length % 7)) % 7;
  for (var day = 1; day <= remainder; day++) {
    cells.add(MonthCell(DateTime(year, month + 2, day), false));
  }
  return cells;
}

String formatMonthTitle(DateTime date) => '${date.year}년 ${date.month}월';

String formatWeekTitle(DateTime date) {
  final days = getWeekDays(date);
  final start = days[0];
  final end = days[6];
  if (start.month == end.month) {
    return '${start.year}년 ${start.month}월 ${start.day}일 - ${end.day}일';
  }
  return '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일';
}

String formatDayTitle(DateTime date) => '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday % 7]})';

int minutesFromTime(String time) {
  final parts = time.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

String timeFromMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String formatTimeLabel(String time) {
  final parts = time.split(':').map(int.parse).toList();
  final h = parts[0], m = parts[1];
  final period = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return m == 0 ? '$period $h12시' : '$period $h12:${m.toString().padLeft(2, '0')}';
}

String formatHourLabel(int hour) {
  final period = hour < 12 ? '오전' : '오후';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $h12시';
}

String formatDurationLabel(int minutes) {
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

String? formatLunarDate(DateTime date) {
  final calendar = KoreanLunarCalendar();
  if (!calendar.setSolarDate(date.year, date.month, date.day)) return null;
  final intercalation = calendar.lunarIntercalation ? '윤 ' : '';
  return '음력 $intercalation${calendar.lunarMonth}. ${calendar.lunarDay}.';
}
