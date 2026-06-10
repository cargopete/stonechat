import Flutter
import UIKit
import PushKit
import flutter_callkit_incoming

// The plugin's payload type is named `Data`, which collides with Foundation.Data
// at the call site; alias it once here so the reference is unambiguous.
private typealias CallkitData = flutter_callkit_incoming.Data

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  PKPushRegistryDelegate
{
  private var voipRegistry: PKPushRegistry?

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
    // Register for PushKit VoIP pushes — the only kind iOS delivers to a killed
    // app and lets ring via CallKit. The token arrives in didUpdate below.
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - PushKit (VoIP) for incoming calls

  func pushRegistry(
    _ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    // The Dart side reads this back via getDevicePushTokenVoIP() to register it
    // with the relay.
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType, completion: @escaping () -> Void
  ) {
    // iOS REQUIRES that every VoIP push report a call to CallKit, synchronously,
    // or it kills the app and eventually stops delivering pushes. The relay only
    // sends VoIP pushes for call offers, so this always has a call to show. The
    // call id matches the offer envelope, so Dart lines this up on answer.
    let dict = payload.dictionaryPayload
    let id = (dict["uuid"] as? String) ?? UUID().uuidString
    let nameCaller = (dict["nameCaller"] as? String) ?? "stonechat"
    let handle = (dict["handle"] as? String) ?? "stonechat"
    let hasVideo = (dict["hasVideo"] as? Bool) ?? false
    var info = [String: Any?]()
    info["id"] = id
    info["nameCaller"] = nameCaller
    info["appName"] = "stonechat"
    info["handle"] = handle
    info["type"] = hasVideo ? 1 : 0
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      CallkitData(args: info), fromPushKit: true)
    completion()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
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
