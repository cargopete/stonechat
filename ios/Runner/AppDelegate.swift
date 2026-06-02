import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Create the CB managers before the Flutter engine so iOS can relaunch us
    // into the background on a BLE event (State Restoration).
    BleTransport.shared.prepareForRestoration()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Hand the native BLE transport a binary messenger so it can wire up the
    // Pigeon HostApi + event channel, and create its CB managers with restore
    // identifiers (enabling background State Restoration).
    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "StonechatBleTransport")?.messenger() {
      BleTransport.shared.attach(messenger: messenger)
    }
  }
}
