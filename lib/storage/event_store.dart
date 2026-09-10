import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';

const _storageKey = 'calendar-events-v1';

String _makeId() {
  final random = Random();
  final suffix = List.generate(7, (_) => random.nextInt(36).toRadixString(36)).join();
  return '${DateTime.now().millisecondsSinceEpoch}-$suffix';
}

/// Local, guest-only event persistence backed by shared_preferences, mirroring
/// calendar_app/lib/useEvents.ts's AsyncStorage-backed hook.
class EventStore extends ChangeNotifier {
  EventMap _events = {};
  bool _loaded = false;

  EventMap get events => _events;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _events = decoded.map(
          (key, value) => MapEntry(key, (value as List).map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList()),
        );
      } catch (_) {
        // ignore corrupted storage
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_events.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())));
    await prefs.setString(_storageKey, encoded);
  }

  /// Adds a new event, or replaces the existing one with matching id (also
  /// removing it from any other date it may have been filed under).
  Future<CalendarEvent> saveEvent(CalendarEvent draft) async {
    if (draft.id.isNotEmpty) {
      for (final key in _events.keys.toList()) {
        _events[key] = _events[key]!.where((e) => e.id != draft.id).toList();
        if (_events[key]!.isEmpty) _events.remove(key);
      }
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = draft.id.isNotEmpty ? draft.id : _makeId();
    final event = draft.copyWith(
      id: id,
      uid: draft.uid ?? id,
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
    );
    final list = [...(_events[draft.date] ?? <CalendarEvent>[]), event];
    list.sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
    _events[draft.date] = list;
    notifyListeners();
    await _persist();
    return event;
  }

  /// Overwrites the whole event map (used by SystemEventsSync to merge in
  /// changes made in the Apple Calendar app).
  Future<void> replaceAll(EventMap events) async {
    _events = events;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteEvent(String dateKey, String id) async {
    final list = (_events[dateKey] ?? <CalendarEvent>[]).where((e) => e.id != id).toList();
    if (list.isEmpty) {
      _events.remove(dateKey);
    } else {
      _events[dateKey] = list;
    }
    notifyListeners();
    await _persist();
  }
}
