import 'package:flutter/material.dart';

import '../logic/date_utils.dart' as date_utils;
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';

/// Port of components/ListView.tsx: a flat, date-grouped agenda of every event.
class EventListView extends StatelessWidget {
  final AppTheme theme;
  final EventMap events;
  final ValueChanged<CalendarEvent> onEventPress;

  const EventListView({super.key, required this.theme, required this.events, required this.onEventPress});

  @override
  Widget build(BuildContext context) {
    final keys = events.keys.where((key) => events[key]!.isNotEmpty).toList()..sort();
    if (keys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Text('일정이 없습니다', style: TextStyle(color: theme.textMuted, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final date = date_utils.parseDateKey(key);
        final dayEvents = [...events[key]!]..sort((a, b) {
            if (a.time == null) return -1;
            if (b.time == null) return 1;
            return date_utils.minutesFromTime(a.time!).compareTo(date_utils.minutesFromTime(b.time!));
          });
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.month}월 ${date.day}일 (${date_utils.weekdays[date.weekday % 7]})',
                style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final event in dayEvents) _EventRow(theme: theme, event: event, onTap: () => onEventPress(event)),
            ],
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final AppTheme theme;
  final CalendarEvent event;
  final VoidCallback onTap;

  const _EventRow({required this.theme, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(event.color);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: withAlpha(color, 0.1),
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(event.title, style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(event.time != null ? date_utils.formatTimeLabel(event.time!) : '종일', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            if (event.recurrence != null) Text('↻ 반복 일정', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            if (event.location != null && event.location!.isNotEmpty)
              Text(event.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            if (event.description != null && event.description!.isNotEmpty)
              Text(event.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            if (event.url != null && event.url!.isNotEmpty)
              Text('↗ ${event.url}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.accent, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
