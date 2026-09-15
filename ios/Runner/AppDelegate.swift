import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let glassAccessibility = GlassAccessibilityStream()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterEventChannel(name: "calendar_app/glass_accessibility",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setStreamHandler(glassAccessibility)
    engineBridge.applicationRegistrar.register(LiquidGlassFactory(), withId: "calendar_app/liquid_glass")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    EventKitChannel.register(with: engineBridge.applicationRegistrar.messenger())
    LiveActivityChannel.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

/// Shares the system preference with Flutter-rendered glass surfaces too.
final class GlassAccessibilityStream: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stopObserving()
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { _ in events(UIAccessibility.isReduceTransparencyEnabled) }
    events(UIAccessibility.isReduceTransparencyEnabled)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    return nil
  }

  private func stopObserving() {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
  }

  deinit { stopObserving() }
}

/// UIKit owns the optical material; Flutter owns the accessible controls above it.
final class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    LiquidGlassPlatformView(frame: frame, arguments: args as? [String: Any] ?? [:])
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let effectView: UIVisualEffectView

  init(frame: CGRect, arguments: [String: Any]) {
    effectView = UIVisualEffectView(frame: frame)
    super.init()
    effectView.overrideUserInterfaceStyle = arguments["dark"] as? Bool == true ? .dark : .light
    effectView.layer.cornerRadius = CGFloat((arguments["radius"] as? NSNumber)?.doubleValue ?? 24)
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    effectView.isUserInteractionEnabled = false
    effectView.isAccessibilityElement = false
    effectView.accessibilityElementsHidden = true
    updateEffect()
    NotificationCenter.default.addObserver(self, selector: #selector(updateEffect),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }

  @objc private func updateEffect() {
    if UIAccessibility.isReduceTransparencyEnabled {
      effectView.effect = nil
      effectView.backgroundColor = .secondarySystemBackground
    } else {
      effectView.backgroundColor = .clear
      if #available(iOS 26.0, *) {
        effectView.effect = UIGlassEffect(style: .regular)
      } else {
        effectView.effect = UIBlurEffect(style: .systemMaterial)
      }
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }
  func view() -> UIView { effectView }
}
