import 'package:calendar_app_flutter/logic/event_dedup.dart';
import 'package:calendar_app_flutter/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(
  String id,
  String title, {
  String? time,
  int duration = 60,
}) => CalendarEvent(
  id: id,
  date: '2026-09-24',
  title: title,
  time: time,
  duration: duration,
  color: '#4285F4',
);

void main() {
  test('removes matching imported events but keeps different times', () {
    final merged = mergeAndDeduplicateEvents(
      {
        '2026-09-24': [event('local:1', '팀 회의', time: '10:00')],
      },
      {
        '2026-09-24': [
          event('import:google:1', '팀회의', time: '10:03', duration: 65),
          event('import:kakao:2', '팀 회의 · 본사', time: '10:00'),
          event('import:notion:3', '팀 회의', time: '14:00'),
        ],
      },
    );
    expect(merged['2026-09-24']!.map((item) => item.id), [
      'local:1',
      'import:notion:3',
    ]);
  });

  test('does not merge different all-day event titles', () {
    final merged = mergeAndDeduplicateEvents(const {}, {
      '2026-09-24': [event('import:a', '추석'), event('import:b', '개천절')],
    });
    expect(merged['2026-09-24'], hasLength(2));
  });

  test('removes imported copies of public holidays and special days', () {
    final filtered = removeSpecialDayDuplicates(
      {
        '2026-09-24': [
          event('import:google:1', '추석 연휴'),
          event('import:google:2', '가족 식사', time: '18:00'),
        ],
        '2026-09-23': [event('import:google:3', '추분')],
      },
      {'2026-09-24': '추석'},
      {'2026-09-23': '추분'},
      const {},
    );
    expect(filtered['2026-09-24']!.map((item) => item.title), ['가족 식사']);
    expect(filtered['2026-09-23'], isEmpty);
  });
}
