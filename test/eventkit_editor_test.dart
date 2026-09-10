import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_app_flutter/native/eventkit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('calendar_app/eventkit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native editor receives selected date and cancellation creates no event',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'presentEventEditor');
        expect(call.arguments['date'], '2026-09-10');
        expect(call.arguments['isAllDay'], true);
        return {'saved': false};
      });
      final result = await EventKit.presentEventEditor(
        DateTime(2026, 9, 10),
        null,
      );
      expect(result.saved, false);
      expect(result.event, isNull);
    },
  );

  test(
    'saved Apple event keeps its local date and time across UTC midnight',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['isAllDay'], false);
        return {
          'saved': true,
          'event': {
            'systemEventId': 'apple-event',
            'title': '미팅',
            'date': '2026-09-11',
            'time': '08:00',
            'isAllDay': false,
            'startsAt': '2026-09-10T23:00:00Z',
            'endsAt': '2026-09-11T00:00:00Z',
            'durationMinutes': 60,
          },
        };
      });
      final result = await EventKit.presentEventEditor(
        DateTime(2026, 9, 11),
        '08:00',
      );
      expect(result.event!.date, '2026-09-11');
      expect(result.event!.time, '08:00');
      expect(result.event!.systemEventId, 'apple-event');
    },
  );

  test('saved without read access does not fabricate a local event', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {'saved': true});
    final result = await EventKit.presentEventEditor(
      DateTime(2026, 9, 10),
      null,
    );
    expect(result.saved, true);
    expect(result.event, isNull);
  });
}
