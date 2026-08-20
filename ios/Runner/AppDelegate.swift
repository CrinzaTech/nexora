import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Black overlay added to the key window while `UIScreen.main.isCaptured`
  /// is true. iOS doesn't expose a `FLAG_SECURE` analogue — the only
  /// reliable way to hide app pixels from screen recording / AirPlay
  /// mirroring is to detect a live capture session and put an opaque
  /// view above everything until it ends.
  private var captureOverlay: UIView?

  /// `false` (the default) keeps the overlay engaged whenever a capture
  /// session is live. Flutter flips this to `true` after the profile
  /// loads with `isScreenCaptureAllowed: true`, at which point we drop
  /// any active overlay and stop reacting to capture events.
  private var captureAllowed: Bool = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    // Register MethodChannel AFTER GeneratedPluginRegistrant so the
    // engine's binaryMessenger is up and Flutter can find us on the
    // very first invocation.
    if let controller = window?.rootViewController as? FlutterViewController {
      let captureChannel = FlutterMethodChannel(
        name: "crinza/screen_capture",
        binaryMessenger: controller.binaryMessenger
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
      guard let self = self else { return }
      let shouldBlock = !self.captureAllowed && UIScreen.main.isCaptured
      if shouldBlock {
        self.attachOverlay()
      } else {
        self.detachOverlay()
      }
    }
  }

  private func attachOverlay() {
    guard captureOverlay == nil, let window = self.window else { return }
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
