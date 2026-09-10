/// Port of calendar_app/lib/password.ts.
class PasswordRule {
  final String label;
  final bool Function(String value) test;
  const PasswordRule(this.label, this.test);
}

final List<PasswordRule> passwordRules = [
  PasswordRule('8자 이상', (value) => value.characters.length >= 8),
  PasswordRule('영문 대문자', (value) => RegExp(r'[A-Z]').hasMatch(value)),
  PasswordRule('영문 소문자', (value) => RegExp(r'[a-z]').hasMatch(value)),
  PasswordRule('숫자', (value) => RegExp(r'[0-9]').hasMatch(value)),
  PasswordRule('특수문자', (value) => value.characters.any((ch) {
        final code = ch.codeUnitAt(0);
        return code >= 33 && code <= 126 && !RegExp(r'[A-Za-z0-9]').hasMatch(ch);
      })),
];

int _utf8ByteLength(String value) {
  var total = 0;
  for (final rune in value.runes) {
    if (rune <= 0x7f) {
      total += 1;
    } else if (rune <= 0x7ff) {
      total += 2;
    } else if (rune <= 0xffff) {
      total += 3;
    } else {
      total += 4;
    }
  }
  return total;
}

bool isStrongPassword(String value) {
  return _utf8ByteLength(value) <= 72 && passwordRules.every((rule) => rule.test(value));
}

extension _Characters on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
