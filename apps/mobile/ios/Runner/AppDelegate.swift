import Flutter
import UIKit

#if canImport(GoogleMaps)
  import GoogleMaps
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    provideGoogleMapsKeyIfConfigured()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// The iOS Maps SDK needs its key before the first map view is created, which is
  /// earlier than Dart runs — so unlike every other setting it cannot come from
  /// `--dart-define`. It is read from `GMSApiKey` in Info.plist, which resolves the
  /// `GOOGLE_MAPS_KEY` build setting supplied by the git-ignored
  /// `ios/Flutter/Maps.xcconfig`.
  ///
  /// An absent or unsubstituted key is a supported state: `Env.mapsEnabled` is
  /// false in the same build, so Dart never asks for a map view.
  private func provideGoogleMapsKeyIfConfigured() {
    #if canImport(GoogleMaps)
      guard
        let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
        !key.isEmpty,
        !key.hasPrefix("$(")
      else { return }

      GMSServices.provideAPIKey(key)
    #endif
  }
}
