import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../theme/app_theme.dart';

class BottomTabBar extends StatelessWidget {
  final AppTheme theme;
  final ViewMode view;
  final ValueChanged<ViewMode> onChange;

  const BottomTabBar({super.key, required this.theme, required this.view, required this.onChange});

  static const _tabs = [
    (ViewMode.day, '일', Icons.today),
    (ViewMode.week, '주', Icons.view_week),
    (ViewMode.month, '월', Icons.calendar_view_month),
    (ViewMode.list, '목록', Icons.list),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: theme.bg, border: Border(top: BorderSide(color: theme.border))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (mode, label, icon) in _tabs)
              Expanded(
                child: InkWell(
                  onTap: () => onChange(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: view == mode ? theme.accent : theme.textMuted),
                        const SizedBox(height: 2),
                        Text(label, style: TextStyle(fontSize: 11, color: view == mode ? theme.accent : theme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
