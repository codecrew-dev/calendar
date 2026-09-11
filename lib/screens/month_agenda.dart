import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/date_utils.dart' as dates;
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import 'month_view.dart';
import '../widgets/liquid_glass.dart';
import 'time_grid_view.dart';

/// Calendar and selected-day agenda share the available screen height.
class MonthAgenda extends StatefulWidget {
  final AppTheme theme;
  final DateTime viewDate;
  final EventMap events;
  final String selectedKey;
  final bool showLunar;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<CalendarEvent> onEventPress;
  final void Function(DateTime, int) onSlotPress;
  const MonthAgenda({
    super.key,
    required this.theme,
    required this.viewDate,
    required this.events,
    required this.selectedKey,
    this.showLunar = false,
    required this.onSelectDate,
    required this.onEventPress,
    required this.onSlotPress,
  });

  @override
  State<MonthAgenda> createState() => _MonthAgendaState();
}

class _MonthAgendaState extends State<MonthAgenda> {
  bool _open = false;
  bool _timeline = false;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final day = dates.parseDateKey(widget.selectedKey);
    final events = [...?widget.events[widget.selectedKey]]
      ..sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
    final rows =
        dates
            .getMonthMatrix(widget.viewDate.year, widget.viewDate.month - 1)
            .length ~/
        7;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = math.min(
          rows * 51.0 + 28,
          constraints.maxHeight * 0.65,
        );
        return PopScope(
          canPop: !_open,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) setState(() => _open = false);
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _open ? compactHeight : constraints.maxHeight,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: MonthView(
                    theme: theme,
                    viewDate: widget.viewDate,
                    events: widget.events,
                    selectedKey: widget.selectedKey,
                    showLunar: widget.showLunar,
                    compact: _open,
                    rowHeight: math.max(
                      90,
                      (constraints.maxHeight - 28) / rows,
                    ),
                    onSelectDate: (key) {
                      setState(() => _open = true);
                      widget.onSelectDate(key);
                    },
                  ),
                ),
              ),
              if (_open)
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: LiquidGlass(
                      radius: 24,
                      child: Column(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) => _drag = 0,
                            onVerticalDragUpdate: (details) =>
                                _drag += details.delta.dy,
                            onVerticalDragEnd: (details) {
                              if (_drag > 40 ||
                                  (details.primaryVelocity ?? 0) > 600) {
                                setState(() => _open = false);
                              }
                            },
                            child: Column(
                              children: [
                                Semantics(
                                  button: true,
                                  label: '일정 목록 접기',
                                  container: true,
                                  child: InkWell(
                                    onTap: () => setState(() => _open = false),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 24,
                                      child: Center(
                                        child: Container(
                                          width: 32,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: theme.textSecondary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${day.month}. ${day.day}. ${dates.weekdays[day.weekday % 7]}',
                                          style: TextStyle(
                                            color: theme.text,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (widget.showLunar &&
                                          dates.formatLunarDate(day) != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(
                                            dates.formatLunarDate(day)!,
                                            style: TextStyle(
                                              color: theme.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _timeline = !_timeline,
                                        ),
                                        style: TextButton.styleFrom(
                                          backgroundColor: theme.bgSecondary,
                                          foregroundColor: theme.textSecondary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _timeline ? '목록' : '시간표',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _timeline
                                ? TimeGridView(
                                    embedded: true,
                                    key: ValueKey(widget.selectedKey),
                                    theme: theme,
                                    days: [day],
                                    events: widget.events,
                                    onSlotPress: widget.onSlotPress,
                                    onEventPress: widget.onEventPress,
                                  )
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      100,
                                    ),
                                    children: [
                                      if (events.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            '일정이 없습니다',
                                            style: TextStyle(
                                              color: theme.textMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      for (final event in events)
                                        _AgendaRow(
                                          theme: theme,
                                          event: event,
                                          onTap: () =>
                                              widget.onEventPress(event),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final AppTheme theme;
  final CalendarEvent event;
  final VoidCallback onTap;
  const _AgendaRow({
    required this.theme,
    required this.event,
    required this.onTap,
  });

  String _clock(int minutes) =>
      '${(minutes ~/ 60) % 12 == 0 ? 12 : (minutes ~/ 60) % 12}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final start = event.time == null ? 0 : dates.minutesFromTime(event.time!);
    final end = start + event.duration;
    return Semantics(
      button: true,
      label: '${event.title} 일정 수정',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            event.time == null
                                ? '종일'
                                : start < 720
                                ? '오전'
                                : '오후',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (event.time != null)
                            Text(
                              _clock(start),
                              style: TextStyle(color: theme.text, fontSize: 13),
                            ),
                        ],
                      ),
                      if (event.time != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              end >= 1440
                                  ? '다음 날'
                                  : start ~/ 720 != end ~/ 720
                                  ? '오후'
                                  : '',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _clock(end),
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: withAlpha(colorFromHex(event.color), 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (event.location?.isNotEmpty ?? false)
                        Text(
                          event.location!,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      if (event.recurrence != null)
                        Text(
                          '↻ 반복 일정',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
