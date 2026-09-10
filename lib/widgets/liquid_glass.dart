import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native Apple glass on iOS; frosted material on other platforms.
/// The foreground stays in Flutter to retain keyboard and screen reader actions.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  /// Platform views cannot reliably sit below Flutter modal routes on iOS.
  /// Set this to false for screens that can present an in-app alert.
  final bool useNative;
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.useNative = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final native = useNative && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: native && !highContrast
                      ? UiKitView(
                          key: ValueKey('glass-$dark-$radius'),
                          viewType: 'calendar_app/liquid_glass',
                          creationParams: {'dark': dark, 'radius': radius},
                          creationParamsCodec: const StandardMessageCodec(),
                        )
                      : BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: highContrast ? 0 : 20,
                            sigmaY: highContrast ? 0 : 20,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  (dark
                                          ? const Color(0xFF252525)
                                          : Colors.white)
                                      .withValues(
                                        alpha: highContrast
                                            ? 1
                                            : dark
                                            ? 0.76
                                            : 0.64,
                                      ),
                              borderRadius: shape,
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: dark ? 0.14 : 0.65,
                                ),
                                width: 0.7,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Material(type: MaterialType.transparency, child: child),
          ],
        ),
      ),
    );
  }
}
