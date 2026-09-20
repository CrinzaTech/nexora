import Flutter
import UIKit

/// iOS 27 terminates apps at launch that are linked against the iOS 27 SDK
/// and still use the legacy `UIApplicationDelegate`-only lifecycle. Declaring
/// this class in `Info.plist` under `UIApplicationSceneManifest` is what
/// opts the app into the `UIScene` lifecycle.
///
/// `FlutterSceneDelegate` (Flutter 3.38+) does all the real work: it builds
/// the window from `Main.storyboard`, wires the `FlutterViewController` to
/// the scene, and forwards scene lifecycle events to plugins. Nothing to
/// add here — the screen-capture overlay lives in `AppDelegate`.
class SceneDelegate: FlutterSceneDelegate {}
