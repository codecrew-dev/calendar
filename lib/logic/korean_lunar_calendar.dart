import 'korean_lunar_data.dart';

const int _lunarSmallMonthDay = 29;
const int _lunarBigMonthDay = 30;
const int _solarSmallYearDay = 365;
const int _solarBigYearDay = 366;
const int _solarLunarDayDiff = 43;
const List<int> _solarDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 29];

const int koreanLunarMinValue = 10000101;
const int koreanLunarMaxValue = 20501118;
const int koreanSolarMinValue = 10000213;
const int koreanSolarMaxValue = 20501231;

/// A minimal, faithful Dart port of the korean-lunar-calendar npm package's
/// solar-to-lunar conversion (the subset used by formatLunarDate). Ported
/// bit-for-bit from its algorithm; see korean_lunar_data.dart for the source.
class KoreanLunarCalendar {
  final Map<int, int> _cumulativeLunarYearDays = {};
  final Map<int, int> _cumulativeSolarYearDays = {};

  int? lunarYear;
  int? lunarMonth;
  int? lunarDay;
  bool lunarIntercalation = false;

  int _lunarData(int year) => koreanLunarData[year - koreanLunarBaseYear];

  int _lunarIntercalationMonth(int lunarData) => (lunarData >> 12) & 15;

  int _lunarYearDays(int year) => (_lunarData(year) >> 17) & 511;

  int _lunarMonthDays(int year, int month, bool isIntercalation) {
    final data = _lunarData(year);
    final isBig = (isIntercalation && _lunarIntercalationMonth(data) == month)
        ? ((data >> 16) & 1) > 0
        : ((data >> (12 - month)) & 1) > 0;
    return isBig ? _lunarBigMonthDay : _lunarSmallMonthDay;
  }

  int _accumulateYearDays(int year, Map<int, int> cache, int Function(int) perYear) {
    final cached = cache[year];
    if (cached != null) return cached;
    const baseYear = koreanLunarBaseYear;
    final previous = cache[year - 1];
    var days = 0;
    if (previous != null && year > baseYear) {
      days = previous + perYear(year);
    } else {
      for (var y = baseYear; y <= year; y++) {
        days += perYear(y);
      }
    }
    cache[year] = days;
    return days;
  }

  int _lunarDaysBeforeBaseYear(int year) => _accumulateYearDays(year, _cumulativeLunarYearDays, _lunarYearDays);

  int _lunarDaysBeforeBaseMonth(int year, int month, bool isIntercalation) {
    var days = 0;
    if (year >= koreanLunarBaseYear && month > 0) {
      for (var m = 1; m <= month; m++) {
        days += _lunarMonthDays(year, m, false);
      }
      if (isIntercalation) {
        final intercalationMonth = _lunarIntercalationMonth(_lunarData(year));
        if (intercalationMonth > 0 && intercalationMonth < month + 1) {
          days += _lunarMonthDays(year, intercalationMonth, true);
        }
      }
    }
    return days;
  }

  int _lunarAbsDays(int year, int month, int day, bool isIntercalation) {
    var days = _lunarDaysBeforeBaseYear(year - 1) + _lunarDaysBeforeBaseMonth(year, month - 1, true) + day;
    if (isIntercalation && _lunarIntercalationMonth(_lunarData(year)) == month) {
      days += _lunarMonthDays(year, month, false);
    }
    return days;
  }

  bool _isSolarIntercalationYear(int lunarData) => ((lunarData >> 30) & 1) > 0;

  int _solarYearDays(int year) => _isSolarIntercalationYear(_lunarData(year)) ? _solarBigYearDay : _solarSmallYearDay;

  int _solarMonthDays(int year, int month) {
    if (month == 2 && _isSolarIntercalationYear(_lunarData(year))) return _solarDays[12];
    return _solarDays[month - 1];
  }

  int _solarDaysBeforeBaseYear(int year) => _accumulateYearDays(year, _cumulativeSolarYearDays, _solarYearDays);

  int _solarDaysBeforeBaseMonth(int year, int month) {
    var days = 0;
    for (var m = 1; m <= month; m++) {
      days += _solarMonthDays(year, m);
    }
    return days;
  }

  int _solarAbsDays(int year, int month, int day) =>
      _solarDaysBeforeBaseYear(year - 1) + _solarDaysBeforeBaseMonth(year, month - 1) + day - _solarLunarDayDiff;

  bool _checkValidSolarDate(int year, int month, int day) {
    if (month <= 0 || month >= 13 || day <= 0) return false;
    final value = year * 10000 + month * 100 + day;
    if (value < koreanSolarMinValue || value > koreanSolarMaxValue) return false;
    if (year == 1582 && month == 10 && day > 4 && day < 15) return false;
    return day <= _solarMonthDays(year, month);
  }

  /// Returns true and populates lunarYear/lunarMonth/lunarDay/lunarIntercalation
  /// on success; false (state unchanged) if the solar date is out of range.
  bool setSolarDate(int solarYear, int solarMonth, int solarDay) {
    if (!_checkValidSolarDate(solarYear, solarMonth, solarDay)) return false;
    final absDays = _solarAbsDays(solarYear, solarMonth, solarDay);
    final lunarYear = absDays >= _lunarAbsDays(solarYear, 1, 1, false) ? solarYear : solarYear - 1;
    var lunarMonth = 0;
    var lunarDay = 0;
    var isIntercalation = false;
    for (var month = 12; month > 0; month--) {
      if (absDays >= _lunarAbsDays(lunarYear, month, 1, false)) {
        lunarMonth = month;
        if (_lunarIntercalationMonth(_lunarData(lunarYear)) == month) {
          isIntercalation = absDays >= _lunarAbsDays(lunarYear, month, 1, true);
        }
        lunarDay = absDays - _lunarAbsDays(lunarYear, lunarMonth, 1, isIntercalation) + 1;
        break;
      }
    }
    this.lunarYear = lunarYear;
    this.lunarMonth = lunarMonth;
    this.lunarDay = lunarDay;
    lunarIntercalation = isIntercalation;
    return true;
  }
}
