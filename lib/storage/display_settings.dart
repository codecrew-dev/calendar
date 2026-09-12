import 'package:shared_preferences/shared_preferences.dart';

enum DisplaySetting { holidays, lunar, solarTerms, anniversaries }

class DisplaySettings {
  static final instance = DisplaySettings();
  final Map<DisplaySetting, bool> _values = {};
  SharedPreferences? _preferences;

  bool enabled(DisplaySetting setting) =>
      _values[setting] ?? (setting == DisplaySetting.holidays);

  String _key(DisplaySetting setting) => 'calendar.display.${setting.name}';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    for (final setting in DisplaySetting.values) {
      _values[setting] =
          preferences.getBool(_key(setting)) ??
          (setting == DisplaySetting.holidays);
    }
  }

  Future<void> setEnabled(DisplaySetting setting, bool value) async {
    _values[setting] = value;
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    if (!await preferences.setBool(_key(setting), value)) {
      throw StateError('표시 설정을 저장하지 못했습니다.');
    }
  }
}
