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
    // Ask the OS for an APNs device token (the relay uses it to wake us). This
    // is independent of the alert-permission prompt; the token arrives in
    // didRegisterForRemoteNotificationsWithDeviceToken. Harmless (logs a failure)
    // until the Push Notifications capability is provisioned.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    PushTokenStore.set(hex)
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("stonechat: APNs registration failed: \(error.localizedDescription)")
    super.application(
      application, didFailToRegisterForRemoteNotificationsWithError: error)
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
