import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Black overlay added to the key window while the screen is being
  /// captured. iOS doesn't expose a `FLAG_SECURE` analogue — the only
  /// reliable way to hide app pixels from screen recording / AirPlay
  /// mirroring is to detect a live capture session and put an opaque
  /// view above everything until it ends.
  private var captureOverlay: UIView?

  /// `false` (the default) keeps the overlay engaged whenever a capture
  /// session is live. Flutter flips this to `true` after the profile
  /// loads with `isScreenCaptureAllowed: true`, at which point we drop
  /// any active overlay and stop reacting to capture events.
  private var captureAllowed: Bool = false

  /// Under the `UIScene` lifecycle the app delegate's own `window` is nil —
  /// the window belongs to the scene (see `SceneDelegate`). Walk the
  /// connected scenes for it instead, falling back to `window` so this
  /// keeps working if the app is ever run without a scene manifest.
  private var hostWindow: UIWindow? {
    if let window { return window }
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return windows.first(where: \.isKeyWindow) ?? windows.first
  }

  /// Plugin and platform-channel registration moved here from
  /// `didFinishLaunchingWithOptions`. With the scene lifecycle the engine
  /// is created before any window exists, so the old
  /// `window?.rootViewController as? FlutterViewController` lookup returned
  /// nil and the capture channel silently never registered. The bridge
  /// hands us the messenger directly, no view controller needed.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let captureChannel = FlutterMethodChannel(
      name: "crinza/screen_capture",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    captureChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setAllowed" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let allowed = (call.arguments as? [String: Any])?["allowed"] as? Bool ?? false
      self?.captureAllowed = allowed
      self?.refreshOverlay()
      result(nil)
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // Engage the secure-by-default posture: assume capture is NOT
    // allowed, attach the overlay if a recording is already in progress
    // at launch, and listen for changes.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStatusChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    refreshOverlay()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func captureStatusChanged() {
    refreshOverlay()
  }

  /// Synchronise overlay state with the current capture status and the
  /// server-controlled `captureAllowed` flag. Idempotent — safe to call
  /// from any of: launch, channel toggle, system notification.
  private func refreshOverlay() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      // Prefer the screen the app is actually on; `UIScreen.main` is
      // deprecated under the scene lifecycle and reports the wrong screen
      // when the app is mirrored or on an external display.
      let isCaptured = self.hostWindow?.screen.isCaptured ?? false
      if !self.captureAllowed && isCaptured {
        self.attachOverlay()
      } else {
        self.detachOverlay()
      }
    }
  }

  private func attachOverlay() {
    guard captureOverlay == nil, let window = hostWindow else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // A small label so the user knows the blackout is intentional, not
    // a crash. White text on black, centred, no chrome.
    let label = UILabel()
    label.text = "Screen recording is disabled in this app."
    label.textColor = .white
    label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24),
    ])

    window.addSubview(overlay)
    captureOverlay = overlay
  }

  private func detachOverlay() {
    captureOverlay?.removeFromSuperview()
    captureOverlay = nil
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
