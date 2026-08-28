import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let screenSecurityChannelName = "mort/native_security"
  private static let privacyShieldTag = 0x4D4F5254

  private var screenSecurityChannel: FlutterMethodChannel?
  private var sensitiveContentActive = false
  private var applicationInactive = true

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    applicationInactive = application.applicationState != .active
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: Self.screenSecurityChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSecureScreen" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let enabled = arguments["enabled"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "The secure-screen state is required.",
            details: nil
          )
        )
        return
      }

      DispatchQueue.main.async {
        guard let self = self else {
          result(
            FlutterError(
              code: "unavailable",
              message: "Screen protection is unavailable.",
              details: nil
            )
          )
          return
        }
        self.sensitiveContentActive = enabled
        self.updatePrivacyShields()
        result(nil)
      }
    }
    screenSecurityChannel = channel
  }

  @objc private func applicationWillResignActive() {
    applicationInactive = true
    updatePrivacyShields()
  }

  @objc private func applicationDidBecomeActive() {
    applicationInactive = false
    updatePrivacyShields()
  }

  @objc private func screenCaptureStateChanged() {
    updatePrivacyShields()
  }

  private func updatePrivacyShields() {
    let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for window in windowScenes.flatMap(\.windows) {
      let shouldShield = sensitiveContentActive && (applicationInactive || window.screen.isCaptured)
      if shouldShield {
        installPrivacyShield(on: window)
      } else {
        removePrivacyShield(from: window)
      }
    }
  }

  private func installPrivacyShield(on window: UIWindow) {
    if let existingShield = window.viewWithTag(Self.privacyShieldTag) {
      window.bringSubviewToFront(existingShield)
      return
    }

    let shield = UIView(frame: window.bounds)
    shield.tag = Self.privacyShieldTag
    shield.accessibilityIdentifier = "mort_privacy_shield"
    shield.backgroundColor = UIColor(red: 0.025, green: 0.025, blue: 0.035, alpha: 1)
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let brandLabel = UILabel()
    brandLabel.translatesAutoresizingMaskIntoConstraints = false
    brandLabel.text = "MORT"
    brandLabel.textColor = UIColor(red: 0.91, green: 0.67, blue: 0.62, alpha: 1)
    brandLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
    brandLabel.accessibilityElementsHidden = true
    shield.addSubview(brandLabel)
    NSLayoutConstraint.activate([
      brandLabel.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
      brandLabel.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
    ])

    window.addSubview(shield)
  }

  private func removePrivacyShield(from window: UIWindow) {
    window.viewWithTag(Self.privacyShieldTag)?.removeFromSuperview()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
