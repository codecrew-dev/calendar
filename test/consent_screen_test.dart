import 'package:calendar_app_flutter/screens/consent_screen.dart';
import 'package:calendar_app_flutter/theme/app_theme.dart';
import 'package:calendar_app_flutter/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('requires all three confirmations and persists explicit acceptance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
      home: ConsentScreen(theme: lightTheme, onAccepted: () => accepted = true),
    ));
    CupertinoButton button() => tester.widget<CupertinoButton>(find.byKey(const ValueKey('consentContinue')));
    final buttonFinder = find.byKey(const ValueKey('consentContinue'));
    final glassFinder = find.ancestor(of: buttonFinder, matching: find.byType(LiquidGlass));
    expect(tester.getSize(buttonFinder).width, tester.getSize(glassFinder).width);
    expect(tester.getCenter(find.text('동의하고 계속하기')).dx,
        closeTo(tester.getCenter(glassFinder).dx, 0.1));
    expect(button().onPressed, isNull);
    await tester.tap(find.text('[필수] 만 14세 이상입니다'));
    await tester.tap(find.text('[필수] 이용약관 동의'));
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.tap(find.text('[필수] 개인정보처리방침 동의'));
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(accepted, isFalse);
    await tester.ensureVisible(find.text('동의하고 계속하기'));
    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ConsentScreen.storageKey), isNotNull);
    expect(prefs.getBool(ConsentScreen.marketingStorageKey), isFalse);
  });
  testWidgets('all consent includes marketing but marketing can be declined', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: ConsentScreen(theme: lightTheme, onAccepted: () {}),
    ));
    await tester.tap(find.text('모두 동의합니다'));
    await tester.pump();
    await tester.ensureVisible(find.text('[선택] 광고성 정보 수신 동의'));
    await tester.tap(find.text('[선택] 광고성 정보 수신 동의'));
    await tester.pump();
    final button = tester.widget<CupertinoButton>(find.byKey(const ValueKey('consentContinue')));
    expect(button.onPressed, isNotNull);
    await tester.ensureVisible(find.text('동의하고 계속하기'));
    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ConsentScreen.marketingStorageKey), isFalse);
  });

}
