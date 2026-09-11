import 'package:flutter/material.dart';

import '../logic/date_utils.dart' as date_utils;
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';

/// Month grid matching the expanded event bars and compact agenda layout.
class MonthView extends StatelessWidget {
  final AppTheme theme;
  final DateTime viewDate;
  final EventMap events;
  final String? selectedKey;
  final bool showLunar;
  final ValueChanged<String> onSelectDate;
  final bool compact;
  final double rowHeight;

  const MonthView({
    super.key,
    required this.theme,
    required this.viewDate,
    required this.events,
    required this.selectedKey,
    this.showLunar = false,
    required this.onSelectDate,
    this.compact = false,
    this.rowHeight = 108,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final cells = date_utils.getMonthMatrix(viewDate.year, viewDate.month - 1);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      date_utils.weekdays[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i == 0
                            ? const Color(0xFFEF4444)
                            : i == 6
                            ? const Color(0xFF3B82F6)
                            : theme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisExtent: compact ? 51 : rowHeight,
          padding: EdgeInsets.zero,
          children: [
            for (final cell in cells)
              _MonthCell(
                theme: theme,
                cell: cell,
                today: today,
                events: events,
                selectedKey: selectedKey,
                showLunar: showLunar,
                onSelectDate: onSelectDate,
                compact: compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  final AppTheme theme;
  final date_utils.MonthCell cell;
  final DateTime today;
  final EventMap events;
  final String? selectedKey;
  final bool showLunar;
  final ValueChanged<String> onSelectDate;
  final bool compact;

  const _MonthCell({
    required this.theme,
    required this.cell,
    required this.today,
    required this.events,
    required this.selectedKey,
    required this.showLunar,
    required this.onSelectDate,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final key = date_utils.toDateKey(cell.date);
    final dayEvents = events[key] ?? const <CalendarEvent>[];
    final isToday = date_utils.isSameDay(cell.date, today);
    final isSelected = selectedKey == key;
    final opacity = cell.inMonth ? 1.0 : 0.35;
    final weekday = cell.date.weekday % 7;

    return InkWell(
      onTap: () => onSelectDate(key),
      child: Container(
        decoration: BoxDecoration(
          color: !compact && isSelected ? theme.bgSecondary : theme.bg,
          border: compact
              ? null
              : Border(top: BorderSide(color: theme.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: compact ? 30 : 18,
              height: compact ? 30 : 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? (theme.isDark
                          ? const Color(0xFFE9E9E7)
                          : const Color(0xFF262629))
                    : (isSelected ? theme.border : null),
              ),
              child: Text(
                '${cell.date.day}',
                style: TextStyle(
                  fontSize: compact ? 14 : 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color:
                      (isToday
                              ? theme.bg
                              : weekday == 0
                              ? const Color(0xFFFF526F)
                              : weekday == 6
                              ? const Color(0xFF7C85FF)
                              : theme.text)
                          .withValues(alpha: isToday ? 1 : opacity),
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (!compact && showLunar)
              Text(
                date_utils
                        .formatLunarDate(cell.date)
                        ?.replaceFirst('음력 ', '') ??
                    '',
                style: TextStyle(
                  color: theme.textMuted.withValues(alpha: opacity),
                  fontSize: 8,
                ),
              ),
            if (!compact)
              Expanded(
                child: Column(
                  children: [
                    for (final event in dayEvents.take(3))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: event.time != null
                              ? Colors.transparent
                              : withAlpha(
                                  colorFromHex(event.color),
                                  0.12 * opacity,
                                ),
                          border: Border(
                            left: BorderSide(
                              color: withAlpha(
                                colorFromHex(event.color),
                                0.6 * opacity,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.text.withValues(alpha: opacity),
                          ),
                        ),
                      ),
                    if (dayEvents.length > 3)
                      Text(
                        '+${dayEvents.length - 3}개 더',
                        style: TextStyle(fontSize: 10, color: theme.textMuted),
                      ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 3,
                children: [
                  for (final color in {
                    for (final e in dayEvents) e.color,
                  }.take(4))
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorFromHex(color),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
