import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar_app_flutter/storage/account_preferences.dart';

void main() {
  test(
    'new device restores account settings and accounts stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final server = <String, Map<String, dynamic>>{};
      AccountPreferences device() => AccountPreferences(
        loadRemote: (user) async => {...?server[user]},
        saveRemote: (user, values) async {
          server[user] = {...?server[user], ...values};
        },
      );
      final first = device();
      await first.selectAccount('a');
      await first.set('calendar.display.lunar', true);
      await first.set('calendar.import.visibility.v1', '{"google|work":false}');
      SharedPreferences.setMockInitialValues({}); // Fresh phone, same server.
      final second = device();
      await second.selectAccount('a');
      expect(await second.sync(), isTrue);
      expect(await second.get('calendar.display.lunar'), true);
      expect(
        await second.get('calendar.import.visibility.v1'),
        '{"google|work":false}',
      );
      await second.selectAccount('b');
      await second.sync();
      expect(await second.get('calendar.display.lunar'), isNull);
      expect(server['b'], isNull);
      await second.selectAccount('a');
      expect(await second.get('calendar.display.lunar'), true);
    },
  );

  test(
    'offline edits survive restart and preserve unrelated remote changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      var offline = true;
      final server = <String, dynamic>{'calendar.display.holidays': true};
      AccountPreferences device() => AccountPreferences(
        loadRemote: (_) async {
          if (offline) throw Exception('offline');
          return {...server};
        },
        saveRemote: (_, values) async => server.addAll(values),
      );
      final first = device();
      await first.selectAccount('a');
      await first.set('calendar.display.lunar', true);
      expect(first.syncSucceeded.value, false);
      expect(await first.get('calendar.display.lunar'), true);
      offline = false;
      server['calendar.display.holidays'] = false;
      final restarted = device();
      await restarted.selectAccount('a');
      expect(await restarted.sync(), true);
      expect(server['calendar.display.lunar'], true);
      expect(await restarted.get('calendar.display.holidays'), false);
    },
  );

  test(
    'legacy device settings migrate once without replacing server values',
    () async {
      SharedPreferences.setMockInitialValues({'calendar.display.lunar': true});
      final server = <String, dynamic>{'calendar.display.lunar': false};
      final prefs = AccountPreferences(
        loadRemote: (_) async => {...server},
        saveRemote: (_, values) async => server.addAll(values),
      );
      await prefs.selectAccount('a');
      await prefs.sync();
      expect(await prefs.get('calendar.display.lunar'), false);
      await prefs.selectAccount('b');
      expect(await prefs.get('calendar.display.lunar'), isNull);
    },
  );
}
