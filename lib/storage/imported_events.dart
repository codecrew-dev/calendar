import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../services/auth_service.dart';

class ImportedEvents extends ChangeNotifier {
  static const _sourcesKey = 'calendar.import.sources.v1';
  EventMap _events = const {};
  final Map<String, List<ImportCalendar>> _sources = {};
  EventMap get events => _events;
  Map<String, List<ImportCalendar>> get sources => _sources;

  Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_sourcesKey);
    if (raw == null) return;
    try {
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final entry in saved.entries) {
        _sources[entry.key] = (entry.value as List)
            .map(
              (value) => ImportCalendar.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList();
      }
    } catch (_) {
      _sources.clear();
    }
  }

  void replace(EventMap events) {
    _events = events;
    notifyListeners();
  }

  void replaceProvider(String provider, EventMap events) {
    final next = <String, List<CalendarEvent>>{};
    for (final entry in _events.entries) {
      final retained = entry.value
          .where((event) => !event.id.startsWith('import:$provider:'))
          .toList();
      if (retained.isNotEmpty) next[entry.key] = retained;
    }
    for (final entry in events.entries) {
      (next[entry.key] ??= []).addAll(entry.value);
    }
    _events = next;
    notifyListeners();
  }

  Future<void> refresh(
    String provider,
    List<ImportCalendar> calendars,
    DateTime from,
    DateTime to,
  ) async {
    final next = <String, List<CalendarEvent>>{};
    for (final calendar in calendars) {
      final items = await AuthService.instance.importEvents(
        provider,
        calendar.id,
        from,
        to,
      );
      for (final item in items) {
        final event = CalendarEvent(
          id: 'import:$provider:${calendar.id}:${item.id}',
          date: item.date,
          title: item.title,
          time: item.time,
          duration: item.duration,
          color: item.color,
          description: '$provider · 읽기 전용',
        );
        (next[event.date] ??= []).add(event);
      }
    }
    replaceProvider(provider, next);
    _sources[provider] = calendars;
    final encoded = jsonEncode({
      for (final entry in _sources.entries)
        entry.key: [
          for (final calendar in entry.value)
            {
              'id': calendar.id,
              'title': calendar.title,
              'color': calendar.color,
            },
        ],
    });
    await (await SharedPreferences.getInstance()).setString(
      _sourcesKey,
      encoded,
    );
  }
}
