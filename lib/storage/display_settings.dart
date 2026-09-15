import 'account_preferences.dart';

enum DisplaySetting { holidays, lunar, solarTerms, anniversaries }

class DisplaySettings {
  static final instance = DisplaySettings();
  final Map<DisplaySetting, bool> _values = {};

  bool enabled(DisplaySetting setting) =>
      _values[setting] ?? (setting == DisplaySetting.holidays);

  String _key(DisplaySetting setting) => 'calendar.display.${setting.name}';

  Future<void> load() async {
    for (final setting in DisplaySetting.values) {
      _values[setting] =
          (await AccountPreferences.instance.get(_key(setting)) as bool?) ??
          (setting == DisplaySetting.holidays);
    }
  }

  Future<void> setEnabled(DisplaySetting setting, bool value) async {
    _values[setting] = value;
    await AccountPreferences.instance.set(_key(setting), value);
  }
}
