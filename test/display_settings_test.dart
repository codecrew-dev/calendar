import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar_app_flutter/storage/display_settings.dart';

void main() {
  test('display settings retain every toggle when reloaded', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = DisplaySettings();
    await settings.load();
    expect(settings.enabled(DisplaySetting.holidays), isTrue);
    for (final setting in DisplaySetting.values) {
      await settings.setEnabled(setting, setting != DisplaySetting.holidays);
    }
    final reopened = DisplaySettings();
    await reopened.load();
    for (final setting in DisplaySetting.values) {
      expect(reopened.enabled(setting), setting != DisplaySetting.holidays);
    }
  });
}
