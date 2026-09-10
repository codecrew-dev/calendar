import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/date_utils.dart' as date_utils;
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';

const double _hourHeight = 56;
const double _labelWidth = 42;

/// Port of components/TimeGridView.tsx: an hour-by-hour grid (day or week),
/// an all-day chip row, and a live "now" line.
class TimeGridView extends StatefulWidget {
  final bool embedded;
  final AppTheme theme;
  final List<DateTime> days;
  final EventMap events;
  final void Function(DateTime date, int hour) onSlotPress;
  final ValueChanged<CalendarEvent> onEventPress;

  const TimeGridView({
    super.key,
    this.embedded = false,
    required this.theme,
    required this.days,
    required this.events,
    required this.onSlotPress,
    required this.onEventPress,
  });

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  final _scrollController = ScrollController();
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hour = widget.days.any((d) => date_utils.isSameDay(d, _now))
          ? (_now.hour - 1).clamp(0, 23)
          : 7;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_hourHeight * hour);
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final colWidth = (width - _labelWidth) / widget.days.length;
    final allDayByDate = widget.days
        .map(
          (d) =>
              (widget.events[date_utils.toDateKey(d)] ??
                      const <CalendarEvent>[])
                  .where((e) => e.time == null)
                  .toList(),
        )
        .toList();
    final hasAllDay = allDayByDate.any((list) => list.isNotEmpty);

    return Column(
      children: [
        if (!widget.embedded)
          Row(
            children: [
              const SizedBox(width: _labelWidth),
              for (final d in widget.days)
                SizedBox(
                  width: colWidth,
                  child: Column(
                    children: [
                      Text(
                        date_utils.weekdays[d.weekday % 7],
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.theme.textMuted,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: date_utils.isSameDay(d, _now)
                              ? widget.theme.accent
                              : null,
                        ),
                        child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 15,
                            color: date_utils.isSameDay(d, _now)
                                ? Colors.white
                                : widget.theme.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (hasAllDay)
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: widget.theme.border),
              ),
            ),
            constraints: const BoxConstraints(minHeight: 34),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _labelWidth,
                  alignment: Alignment.center,
                  color: widget.theme.bgSecondary,
                  child: Text(
                    '하루종일',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: widget.theme.textSecondary,
                    ),
                  ),
                ),
                for (var i = 0; i < widget.days.length; i++)
                  SizedBox(
                    width: colWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (final e in allDayByDate[i])
                            _AllDayChip(
                              theme: widget.theme,
                              event: e,
                              onTap: () => widget.onEventPress(e),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Column(
                      children: [
                        for (final h in date_utils.hoursOfDay)
                          SizedBox(
                            height: _hourHeight,
                            child: h == 0
                                ? null
                                : Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        date_utils.formatHourLabel(h),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: widget.theme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  for (final d in widget.days)
                    _DayColumn(
                      theme: widget.theme,
                      day: d,
                      width: colWidth,
                      now: _now,
                      events: widget.events,
                      onSlotPress: widget.onSlotPress,
                      onEventPress: widget.onEventPress,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AllDayChip extends StatelessWidget {
  final AppTheme theme;
  final CalendarEvent event;
  final VoidCallback onTap;
  const _AllDayChip({
    required this.theme,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = eventCardTone(colorFromHex(event.color), theme);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tone.title,
              ),
            ),
            if (event.location != null && event.location!.isNotEmpty)
              Text(
                event.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: tone.detail),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final AppTheme theme;
  final DateTime day;
  final double width;
  final DateTime now;
  final EventMap events;
  final void Function(DateTime date, int hour) onSlotPress;
  final ValueChanged<CalendarEvent> onEventPress;

  const _DayColumn({
    required this.theme,
    required this.day,
    required this.width,
    required this.now,
    required this.events,
    required this.onSlotPress,
    required this.onEventPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateKey = date_utils.toDateKey(day);
    final timedEvents = (events[dateKey] ?? const <CalendarEvent>[])
        .where((e) => e.time != null)
        .toList();
    final isToday = date_utils.isSameDay(day, now);
    final nowMinutes = now.hour * 60 + now.minute;

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Column(
            children: [
              for (final h in date_utils.hoursOfDay)
                InkWell(
                  onTap: () => onSlotPress(day, h),
                  child: Container(
                    height: _hourHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.border, width: 0.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final e in timedEvents)
            _EventBlock(theme: theme, event: e, onTap: () => onEventPress(e)),
          if (isToday)
            Positioned(
              top: (nowMinutes / 60) * _hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 1.5, color: theme.danger),
            ),
        ],
      ),
    );
  }
}

class _EventBlock extends StatelessWidget {
  final AppTheme theme;
  final CalendarEvent event;
  final VoidCallback onTap;
  const _EventBlock({
    required this.theme,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = eventCardTone(colorFromHex(event.color), theme);
    final startMin = date_utils.minutesFromTime(event.time!);
    final top = (startMin / 60) * _hourHeight;
    final height = ((event.duration / 60) * _hourHeight).clamp(
      22,
      double.infinity,
    );
    return Positioned(
      top: top,
      left: 2,
      right: 12,
      height: height.toDouble(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: height < 30 ? 2 : 6,
          ),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tone.title,
                ),
              ),
              if (height > 38 &&
                  event.location != null &&
                  event.location!.isNotEmpty)
                Text(
                  event.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tone.detail),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
