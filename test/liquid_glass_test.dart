import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_app_flutter/widgets/liquid_glass.dart';

void main() {
  testWidgets('system transparency changes remove blur and preserve taps', (
    tester,
  ) async {
    const channel = MethodChannel('calendar_app/glass_accessibility');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlass(
            useNative: false,
            child: TextButton(onPressed: () => taps++, child: const Text('검색')),
          ),
        ),
      ),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    Future<void> preference(bool value) async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(value),
        (_) {},
      );
      await tester.pump();
    }

    await preference(true);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    await tester.tap(find.text('검색'));
    expect(taps, 1);
    await preference(false);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
