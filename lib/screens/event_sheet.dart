import 'package:flutter/material.dart';

import '../logic/date_utils.dart' as date_utils;
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';

/// Core-fields port of components/EventSheet.tsx + EventOptions.tsx +
/// EventDetailFields.tsx: title, location, all-day, start/end date+time,
/// color, recurrence (frequency + until), notes, url. Travel time, invitees,
/// and attachments are Phase 2.
class EventSheet extends StatefulWidget {
  final AppTheme theme;
  final CalendarEvent? draft;
  final bool isEditing;
  final DateTime initialDate;
  final String? initialTime;
  final void Function(CalendarEvent event) onSave;
  final void Function(String id, String date) onDelete;

  const EventSheet({
    super.key,
    required this.theme,
    required this.draft,
    required this.isEditing,
    required this.initialDate,
    required this.initialTime,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<EventSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _urlController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late bool _isAllDay;
  late TimeOfDay _startTime;
  late int _durationMinutes;
  late String _color;
  RepeatFrequency? _frequency;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _titleController = TextEditingController(text: draft?.title ?? '');
    _locationController = TextEditingController(text: draft?.location ?? '');
    _urlController = TextEditingController(text: draft?.url ?? '');
    _descriptionController = TextEditingController(text: draft?.description ?? '');
    _date = draft != null ? date_utils.parseDateKey(draft.date) : widget.initialDate;
    final time = draft?.time ?? widget.initialTime;
    _isAllDay = time == null;
    _startTime = time != null ? TimeOfDay(hour: int.parse(time.split(':')[0]), minute: int.parse(time.split(':')[1])) : const TimeOfDay(hour: 9, minute: 0);
    _durationMinutes = draft?.duration ?? 60;
    _color = draft?.color ?? colorToHex(palette[0].value);
    _frequency = draft?.recurrence?.frequency;
    _until = draft?.recurrence?.until != null ? date_utils.parseDateKey(draft!.recurrence!.until!) : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(context: context, initialDate: _until ?? _date, firstDate: _date, lastDate: DateTime(2100));
    if (picked != null) setState(() => _until = picked);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final timeString = _isAllDay ? null : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final event = CalendarEvent(
      id: widget.draft?.id ?? '',
      date: date_utils.toDateKey(_date),
      title: title,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      time: timeString,
      duration: _isAllDay ? 24 * 60 : _durationMinutes,
      color: _color,
      recurrence: _frequency != null ? EventRecurrence(frequency: _frequency!, until: _until != null ? date_utils.toDateKey(_until!) : null) : null,
      systemEventId: widget.draft?.systemEventId,
      systemCalendarId: widget.draft?.systemCalendarId,
      uid: widget.draft?.uid,
      createdAt: widget.draft?.createdAt,
    );
    widget.onSave(event);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: theme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.isEditing ? '일정 수정' : '새 일정', style: TextStyle(color: theme.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  if (widget.isEditing && widget.draft != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.danger),
                      onPressed: () => widget.onDelete(widget.draft!.id, widget.draft!.date),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                autofocus: !widget.isEditing,
                style: TextStyle(color: theme.text),
                decoration: InputDecoration(hintText: '제목', hintStyle: TextStyle(color: theme.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                style: TextStyle(color: theme.text),
                decoration: InputDecoration(hintText: '위치', hintStyle: TextStyle(color: theme.textMuted)),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('종일', style: TextStyle(color: theme.text)),
                value: _isAllDay,
                onChanged: (value) => setState(() => _isAllDay = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('날짜', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                trailing: Text(date_utils.toDateKey(_date), style: TextStyle(color: theme.text)),
                onTap: _pickDate,
              ),
              if (!_isAllDay) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('시작 시간', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                  trailing: Text(_startTime.format(context), style: TextStyle(color: theme.text)),
                  onTap: _pickTime,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('길이', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                  trailing: Text(date_utils.formatDurationLabel(_durationMinutes), style: TextStyle(color: theme.text)),
                  onTap: () async {
                    final options = [15, 30, 60, 90, 120, 180];
                    final picked = await showModalBottomSheet<int>(
                      context: context,
                      builder: (context) => ListView(
                        shrinkWrap: true,
                        children: [for (final m in options) ListTile(title: Text(date_utils.formatDurationLabel(m)), onTap: () => Navigator.pop(context, m))],
                      ),
                    );
                    if (picked != null) setState(() => _durationMinutes = picked);
                  },
                ),
              ],
              const SizedBox(height: 12),
              Text('색상', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                children: [
                  for (final entry in palette)
                    GestureDetector(
                      onTap: () => setState(() => _color = colorToHex(entry.value)),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: _color.toUpperCase() == colorToHex(entry.value) ? Border.all(color: theme.text, width: 2) : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('반복', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _RepeatChip(label: '안함', selected: _frequency == null, onTap: () => setState(() { _frequency = null; _until = null; }), theme: theme),
                  for (final freq in RepeatFrequency.values)
                    _RepeatChip(label: _frequencyLabel(freq), selected: _frequency == freq, onTap: () => setState(() => _frequency = freq), theme: theme),
                ],
              ),
              if (_frequency != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('반복 종료', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                  trailing: Text(_until != null ? date_utils.toDateKey(_until!) : '없음', style: TextStyle(color: theme.text)),
                  onTap: _pickUntil,
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                style: TextStyle(color: theme.text),
                decoration: InputDecoration(hintText: 'URL', hintStyle: TextStyle(color: theme.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(color: theme.text),
                decoration: InputDecoration(hintText: '메모', hintStyle: TextStyle(color: theme.textMuted)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _frequencyLabel(RepeatFrequency freq) {
    switch (freq) {
      case RepeatFrequency.daily:
        return '매일';
      case RepeatFrequency.weekly:
        return '매주';
      case RepeatFrequency.biweekly:
        return '격주';
      case RepeatFrequency.monthly:
        return '매월';
      case RepeatFrequency.yearly:
        return '매년';
    }
  }
}

class _RepeatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTheme theme;
  const _RepeatChip({required this.label, required this.selected, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: selected ? theme.accent : theme.text),
    );
  }
}
