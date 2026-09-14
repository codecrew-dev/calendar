import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import '../models/calendar_event.dart';
import 'liquid_glass.dart';

class TopBar extends StatefulWidget {
  static void _ignoreView(ViewMode _) {}

  final AppTheme theme;
  final String title;
  final DateTime selectedDate;
  final VoidCallback onPrev, onNext, onToday, onMenu, onSearch;
  final ViewMode view;
  final ValueChanged<ViewMode> onViewChanged;
  final ValueChanged<DateTime> onDateSelected;
  const TopBar({
    super.key,
    required this.theme,
    required this.title,
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onMenu,
    required this.onSearch,
    this.view = ViewMode.month,
    this.onViewChanged = _ignoreView,
    required this.onDateSelected,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _glassIconButton(
                tooltip: '캘린더 메뉴',
                icon: Icons.menu,
                onPressed: widget.onMenu,
                color: theme.text,
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showDatePicker(context),
                    child: Column(
                      children: [
                        Text(
                          '${widget.title} ▾',
                          maxLines: 1,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '전체 일정',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _glassIconButton(
                tooltip: '일정 검색',
                icon: Icons.search,
                onPressed: widget.onSearch,
                color: theme.text,
              ),
              _glassIconButton(
                tooltip: '보기 방식: ${_viewLabel(widget.view)}',
                icon: _viewIcon(widget.view),
                onPressed: () => widget.onViewChanged(_nextView(widget.view)),
                color: theme.text,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _viewLabel(ViewMode view) => switch (view) {
    ViewMode.list => '목록형',
    ViewMode.week => '여러날',
    ViewMode.day => '하루',
    ViewMode.month => '월간',
  };

  IconData _viewIcon(ViewMode view) => switch (view) {
    ViewMode.month => CupertinoIcons.calendar,
    ViewMode.list => CupertinoIcons.list_bullet,
    ViewMode.week => CupertinoIcons.rectangle_grid_2x2,
    ViewMode.day => CupertinoIcons.calendar_today,
  };

  ViewMode _nextView(ViewMode view) => switch (view) {
    ViewMode.month => ViewMode.list,
    ViewMode.list => ViewMode.week,
    ViewMode.week => ViewMode.day,
    ViewMode.day => ViewMode.month,
  };

  Future<void> _showDatePicker(BuildContext context) async {
    var picked = widget.selectedDate;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: 330,
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: CupertinoColors.systemRed),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        widget.onDateSelected(DateTime.now());
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text(
                        '오늘',
                        style: TextStyle(color: CupertinoColors.label),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        widget.onDateSelected(picked);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text(
                        '완료',
                        style: TextStyle(color: CupertinoColors.activeBlue),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  minimumDate: DateTime(2000),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (date) => picked = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return LiquidGlass(
      // A native iOS platform view can remain above Scaffold's drawer layer.
      // Keep top-bar controls in Flutter so the drawer covers them completely.
      useNative: false,
      radius: 20,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
