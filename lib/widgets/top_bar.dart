import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'liquid_glass.dart';

class TopBar extends StatefulWidget {
  final AppTheme theme;
  final String title;
  final VoidCallback onPrev, onNext, onToday, onMenu, onSearch;
  const TopBar({
    super.key,
    required this.theme,
    required this.title,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onMenu,
    required this.onSearch,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  bool _navigationOpen = false;

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
              IconButton(
                tooltip: '캘린더 메뉴',
                icon: Icon(Icons.menu, size: 20, color: theme.text),
                onPressed: widget.onMenu,
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: _navigationOpen,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _navigationOpen = !_navigationOpen),
                    child: Column(
                      children: [
                        Text(
                          '${widget.title} ${_navigationOpen ? '▴' : '▾'}',
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
              IconButton(
                tooltip: '일정 검색',
                icon: Icon(Icons.search, size: 22, color: theme.text),
                onPressed: widget.onSearch,
              ),
            ],
          ),
          if (_navigationOpen)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: LiquidGlass(
                radius: 99,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '이전 기간',
                      onPressed: widget.onPrev,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    TextButton(
                      onPressed: widget.onToday,
                      child: Text(
                        '오늘',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 기간',
                      onPressed: widget.onNext,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
