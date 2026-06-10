import CoreBluetooth
import Flutter
import Foundation
import UIKit
import UserNotifications

/// Fixed app-level identifiers. These are compile-time constants (not supplied
/// by Dart at runtime) precisely because State Restoration requires the CB
/// managers to be created during `didFinishLaunching` — before the Flutter
/// engine, and thus before any Dart-supplied config, exists. `TransportConfig`
/// from Dart still carries them so the Dart layer can reason about them, but
/// Swift is the source of truth.
enum BleConstants {
  /// Custom 128-bit GATT service UUID. Generate your own for a real deployment.
  static let serviceUUID = CBUUID(string: "9F2A1C00-5B3E-4D7A-8C21-7E0B6A4F1D90")
  /// Single bidirectional write + notify characteristic.
  static let characteristicUUID = CBUUID(string: "9F2A1C01-5B3E-4D7A-8C21-7E0B6A4F1D90")
  static let centralRestoreId = "com.stonechat.transport.central"
  static let peripheralRestoreId = "com.stonechat.transport.peripheral"
}

/// Dual-role Core Bluetooth transport: every device runs *both* a
/// `CBPeripheralManager` (advertises the service, exposes one write/notify
/// characteristic) and a `CBCentralManager` (scans, connects, subscribes), so
/// whichever device is awake/foreground can drive the exchange. Implements the
/// Pigeon `TransportHostApi`.
final class BleTransport: NSObject {
  static let shared = BleTransport()

  private let events = TransportEventStreamHandler()
  private let reassembler = FragmentReassembler()

  private var central: CBCentralManager?
  private var peripheralManager: CBPeripheralManager?

  private var displayName = "stonechat"

  // Peripheral (GATT server) side.
  private var localCharacteristic: CBMutableCharacteristic?
  private var subscribedCentrals: [String: CBCentral] = [:]
  private var wantsAdvertising = false
  /// Frames that `updateValue` refused (queue full); flushed on
  /// `peripheralManagerIsReady(toUpdateSubscribers:)`.
  private var pendingNotifications: [Data] = []

  // Central (GATT client) side.
  private var peripherals: [String: CBPeripheral] = [:]
  private var remoteCharacteristics: [String: CBCharacteristic] = [:]
  private var wantsScanning = false
  /// Write-without-response frames awaiting room in the link's buffer, keyed by
  /// peripheral; paced via `canSendWriteWithoutResponse` so large payloads (e.g.
  /// photos) aren't dropped on overflow.
  private var pendingWrites: [ObjectIdentifier: [Data]] = [:]

  private override init() { super.init() }

  // MARK: - Wiring

  /// Called from `AppDelegate` at launch. Registers the Pigeon APIs and creates
  /// both managers with restore identifiers so iOS can relaunch us on a BLE
  /// event. Safe to call once.
  func attach(messenger: FlutterBinaryMessenger) {
    TransportHostApiSetup.setUp(binaryMessenger: messenger, api: self)
    StreamTransportEventsStreamHandler.register(with: messenger, streamHandler: events)
    // Suppress the notification prompt under the screenshot harness so it never
    // photobombs a captured screen. Never set in a real build.
    if ProcessInfo.processInfo.environment["SCREENSHOT"] == nil {
      UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    ensureManagers()
  }

  /// Creates the CB managers (with restore identifiers) without needing the
  /// Flutter engine. Call from `didFinishLaunchingWithOptions` so iOS can
  /// relaunch us into the background on a BLE event and deliver
  /// `willRestoreState`.
  func prepareForRestoration() {
    ensureManagers()
  }

  private func ensureManagers() {
    if central == nil {
      central = CBCentralManager(
        delegate: self,
        queue: nil,
        options: [CBCentralManagerOptionRestoreIdentifierKey: BleConstants.centralRestoreId]
      )
    }
    if peripheralManager == nil {
      peripheralManager = CBPeripheralManager(
        delegate: self,
        queue: nil,
        options: [CBPeripheralManagerOptionRestoreIdentifierKey: BleConstants.peripheralRestoreId]
      )
    }
  }

  // MARK: - Sending

  /// Splits [data] and writes it to the peer, whether they're connected to us
  /// as a peripheral (we notify) or we connected to them as a central (we
  /// write). Returns true if at least the first frame was dispatched.
  private func send(_ data: Data, to peerId: String) -> Bool {
    let messageId = Self.uuidBytes(UUID())

    if let peripheral = peripherals[peerId], let characteristic = remoteCharacteristics[peerId] {
      let maxLen = peripheral.maximumWriteValueLength(for: .withoutResponse)
      let frames = TransportFragmenter.split(data, messageId: messageId, maxFrameSize: maxLen)
      // Queue all frames and pace them out — writing hundreds in a tight loop
      // overflows Core Bluetooth's small buffer and silently drops the excess,
      // which is exactly why large payloads (photos) never arrived.
      pendingWrites[ObjectIdentifier(peripheral), default: []].append(contentsOf: frames)
      drainWrites(peripheral, characteristic)
      return true
    }

    if let central = subscribedCentrals[peerId], let characteristic = localCharacteristic {
      let maxLen = central.maximumUpdateValueLength
      let frames = TransportFragmenter.split(data, messageId: messageId, maxFrameSize: maxLen)
      for frame in frames {
        let ok = peripheralManager?.updateValue(
          frame, for: characteristic, onSubscribedCentrals: [central]) ?? false
        if !ok { pendingNotifications.append(frame) }
      }
      return true
    }

    return false
  }

  /// Writes queued frames while the peripheral can accept write-without-response
  /// packets, pausing when the buffer is full. Core Bluetooth calls
  /// `peripheralIsReady(toSendWriteWithoutResponse:)` when there's room again,
  /// which resumes the drain — so every frame eventually goes out, in order.
  private func drainWrites(_ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) {
    let key = ObjectIdentifier(peripheral)
    while peripheral.canSendWriteWithoutResponse,
          let frame = pendingWrites[key]?.first {
      pendingWrites[key] = Array((pendingWrites[key] ?? []).dropFirst())
      peripheral.writeValue(frame, for: characteristic, type: .withoutResponse)
    }
  }

  // MARK: - Inbound

  /// Handles a fully reassembled envelope from [peerId]. Emits to Dart when the
  /// UI is listening; otherwise persists + fires a local notification (the
  /// background State-Restoration path where Dart is not running).
  private func handleInbound(_ envelope: Data, from peerId: String) {
    let event = EnvelopeReceivedEvent(
      peerId: peerId,
      envelope: FlutterStandardTypedData(bytes: envelope),
      receivedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
    )
    // Hand the envelope to Dart if it's listening (foreground), otherwise stash
    // it in the inbox for the next drain. EITHER way, alert the user if the app
    // isn't on screen — the previous code only notified when no Dart listener
    // existed, so a backgrounded-but-alive app stayed silent (the actual bug).
    if events.hasListener {
      events.emit(event)
    } else {
      persistForLater(envelope, from: peerId)
    }
    maybeNotify(for: envelope)
  }

  /// Background path: drop the envelope into the App Group inbox for Dart to
  /// drain on next launch/resume.
  private func persistForLater(_ envelope: Data, from peerId: String) {
    EnvelopeInbox.write(envelope)
  }

  /// Posts a local notification for an inbound message when the app is not in
  /// the foreground. Only user-visible messages/photos qualify (acks, reads,
  /// hellos and name announcements stay silent), and only if the user actually
  /// granted notification permission.
  private func maybeNotify(for envelope: Data) {
    guard envelope.count > 1 else { return }
    let type = envelope[envelope.startIndex + 1]  // version(1) | type(1) | …
    guard type == 0 || type == 8 else { return }  // 0 = message, 8 = image
    let title = senderName(from: envelope)
    let body = type == 8 ? "Sent a photo" : "New message"
    DispatchQueue.main.async {
      // The foreground UI shows messages live, so only alert when backgrounded.
      if UIApplication.shared.applicationState == .active { return }
      let center = UNUserNotificationCenter.current()
      center.getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = .default
          center.add(UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil))
        default:
          break  // Permission not granted — nothing we can do.
        }
      }
    }
  }

  /// Best-effort sender label from the cleartext envelope header. Layout:
  /// version(1) + type(1) + messageId(16) + senderId(32) + …, so `senderId`
  /// is the 32 bytes at offset 18 — readable without decryption.
  private func senderName(from envelope: Data) -> String {
    let start = 18
    let length = 32
    guard envelope.count >= start + length else { return "New message" }
    let senderId = envelope.subdata(in: start..<(start + length))
    let hex = senderId.map { String(format: "%02x", $0) }.joined()
    return PeerNameCache.name(for: hex) ?? "Peer \(hex.prefix(8))"
  }
}

// MARK: - TransportHostApi

extension BleTransport: TransportHostApi {
  func configure(config: TransportConfig, completion: @escaping (Result<Void, Error>) -> Void) {
    displayName = config.displayName
    ensureManagers()
    completion(.success(()))
  }

  func startAdvertising() throws {
    wantsAdvertising = true
    startAdvertisingIfReady()
  }

  func stopAdvertising() throws {
    wantsAdvertising = false
    peripheralManager?.stopAdvertising()
  }

  func startScanning() throws {
    wantsScanning = true
    startScanningIfReady()
    reconnectKnownPeripherals()
  }

  /// Re-arms connections to peers we already know about. Called whenever the app
  /// comes back to the foreground, so a link that died while backgrounded is
  /// re-established promptly without waiting for a fresh advertisement scan.
  private func reconnectKnownPeripherals() {
    guard let central = central, central.state == .poweredOn else { return }
    // Pick up peripherals iOS still considers connected at the system level.
    for p in central.retrieveConnectedPeripherals(withServices: [BleConstants.serviceUUID]) {
      peripherals[p.identifier.uuidString] = p
      p.delegate = self
    }
    // Re-issue a pending connect for every known peer not already wired up.
    for (id, p) in peripherals where remoteCharacteristics[id] == nil {
      central.connect(p, options: [
        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
        CBConnectPeripheralOptionNotifyOnNotificationKey: true,
      ])
    }
  }

  func stopScanning() throws {
    wantsScanning = false
    central?.stopScan()
  }

  func connect(peerId: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let peripheral = peripherals[peerId] else {
      completion(.failure(PigeonError(code: "unknown_peer", message: "No such peer \(peerId)", details: nil)))
      return
    }
    central?.connect(peripheral, options: [
      CBConnectPeripheralOptionNotifyOnConnectionKey: true,
      CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
      CBConnectPeripheralOptionNotifyOnNotificationKey: true,
    ])
    completion(.success(()))
  }

  func disconnect(peerId: String) throws {
    if let peripheral = peripherals[peerId] {
      central?.cancelPeripheralConnection(peripheral)
    }
  }

  func sendEnvelope(
    peerId: String, envelope: FlutterStandardTypedData,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    completion(.success(send(envelope.data, to: peerId)))
  }

  func connectedPeers() throws -> [String] {
    Array(Set(remoteCharacteristics.keys).union(subscribedCentrals.keys))
  }

  func inboxDirectoryPath() throws -> String? {
    SharedContainer.inboxURL()?.path
  }

  func cachePeerName(identityHex: String, name: String) throws {
    PeerNameCache.set(name, for: identityHex)
  }

  func pushToken() throws -> String? {
    PushTokenStore.token
  }
}

// MARK: - Helpers

extension BleTransport {
  private func startAdvertisingIfReady() {
    guard wantsAdvertising,
      let pm = peripheralManager, pm.state == .poweredOn, localCharacteristic != nil
    else { return }
    pm.startAdvertising([
      CBAdvertisementDataServiceUUIDsKey: [BleConstants.serviceUUID],
      CBAdvertisementDataLocalNameKey: displayName,
    ])
  }

  private func startScanningIfReady() {
    guard wantsScanning, let central = central, central.state == .poweredOn else { return }
    // A background scan MUST specify the service UUID; nil-services delivers
    // nothing while backgrounded.
    central.scanForPeripherals(
      withServices: [BleConstants.serviceUUID],
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
  }

  private func publishGattService() {
    guard let pm = peripheralManager, pm.state == .poweredOn else { return }
    // If State Restoration already handed us back the characteristic, keep it —
    // re-adding would discard the restored service the system republished.
    if localCharacteristic != nil { return }
    let characteristic = CBMutableCharacteristic(
      type: BleConstants.characteristicUUID,
      properties: [.write, .writeWithoutResponse, .notify],
      value: nil,
      permissions: [.writeable])
    let service = CBMutableService(type: BleConstants.serviceUUID, primary: true)
    service.characteristics = [characteristic]
    pm.removeAllServices()
    pm.add(service)
    localCharacteristic = characteristic
  }

  fileprivate func emitConnection(_ peerId: String, _ state: PeerConnectionState) {
    events.emit(PeerConnectionEvent(peerId: peerId, state: state))
  }

  fileprivate func mapAdapterState(_ state: CBManagerState) -> BleAdapterState {
    switch state {
    case .resetting: return .resetting
    case .unsupported: return .unsupported
    case .unauthorized: return .unauthorized
    case .poweredOff: return .poweredOff
    case .poweredOn: return .poweredOn
    default: return .unknown
    }
  }
}

// MARK: - CBCentralManagerDelegate

extension BleTransport: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    events.emit(AdapterStateEvent(state: mapAdapterState(central.state)))
    if central.state == .poweredOn { startScanningIfReady() }
  }

  func centralManager(
    _ central: CBCentralManager, willRestoreState dict: [String: Any]
  ) {
    if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      for peripheral in restored {
        peripheral.delegate = self
        peripherals[peripheral.identifier.uuidString] = peripheral
        // Re-drive the discovery → characteristic → subscribe chain so an
        // already-connected restored peripheral resumes delivering notifies.
        if peripheral.state == .connected {
          peripheral.discoverServices([BleConstants.serviceUUID])
        }
      }
    }
    wantsScanning = true
  }

  func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    let id = peripheral.identifier.uuidString
    peripherals[id] = peripheral
    peripheral.delegate = self
    let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
    events.emit(PeerDiscoveredEvent(peer: PeerInfo(peerId: id, name: name, rssi: RSSI.int64Value)))
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    emitConnection(peripheral.identifier.uuidString, .connected)
    peripheral.discoverServices([BleConstants.serviceUUID])
  }

  func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    let id = peripheral.identifier.uuidString
    remoteCharacteristics.removeValue(forKey: id)
    pendingWrites.removeValue(forKey: ObjectIdentifier(peripheral))
    emitConnection(id, .disconnected)
    // Persistent reconnect: a connect with no timeout stays pending and
    // re-establishes automatically the moment the peer is back in range, so a
    // dropped link heals itself without the user doing anything.
    reconnect(peripheral)
  }

  func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    // Keep trying — same persistent-reconnect intent as a clean disconnect.
    reconnect(peripheral)
  }

  /// Re-issues a pending connection to a known peripheral.
  private func reconnect(_ peripheral: CBPeripheral) {
    guard peripherals[peripheral.identifier.uuidString] != nil else { return }
    central?.connect(peripheral, options: [
      CBConnectPeripheralOptionNotifyOnConnectionKey: true,
      CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
      CBConnectPeripheralOptionNotifyOnNotificationKey: true,
    ])
  }
}

// MARK: - CBPeripheralDelegate (central role: talking to a remote peripheral)

extension BleTransport: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let service = peripheral.services?.first(where: { $0.uuid == BleConstants.serviceUUID })
    else { return }
    peripheral.discoverCharacteristics([BleConstants.characteristicUUID], for: service)
  }

  /// The link can accept more write-without-response packets — resume draining
  /// any queued frames for this peripheral.
  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    guard let characteristic = remoteCharacteristics[peripheral.identifier.uuidString]
    else { return }
    drainWrites(peripheral, characteristic)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    guard
      let characteristic = service.characteristics?.first(where: {
        $0.uuid == BleConstants.characteristicUUID
      })
    else { return }
    remoteCharacteristics[peripheral.identifier.uuidString] = characteristic
    peripheral.setNotifyValue(true, for: characteristic)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    guard let value = characteristic.value else { return }
    if let envelope = reassembler.ingest(value) {
      handleInbound(envelope, from: peripheral.identifier.uuidString)
    }
  }
}

// MARK: - CBPeripheralManagerDelegate (peripheral role: serving remote centrals)

extension BleTransport: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn {
      publishGattService()
      startAdvertisingIfReady()
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
    // Recover the characteristic the system republished, so `publishGattService`
    // doesn't clobber it and notifies keep flowing to subscribed centrals.
    if let services =
      dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService]
    {
      for service in services where service.uuid == BleConstants.serviceUUID {
        let restored = service.characteristics?.compactMap { $0 as? CBMutableCharacteristic }
        if let characteristic = restored?.first(where: {
          $0.uuid == BleConstants.characteristicUUID
        }) {
          localCharacteristic = characteristic
        }
      }
    }
    wantsAdvertising = true
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]
  ) {
    for request in requests {
      let id = request.central.identifier.uuidString
      subscribedCentrals[id] = request.central
      if let value = request.value, let envelope = reassembler.ingest(value) {
        handleInbound(envelope, from: id)
      }
    }
    peripheral.respond(to: requests[0], withResult: .success)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, central: CBCentral,
    didSubscribeTo characteristic: CBCharacteristic
  ) {
    subscribedCentrals[central.identifier.uuidString] = central
    emitConnection(central.identifier.uuidString, .connected)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, central: CBCentral,
    didUnsubscribeFrom characteristic: CBCharacteristic
  ) {
    subscribedCentrals.removeValue(forKey: central.identifier.uuidString)
    emitConnection(central.identifier.uuidString, .disconnected)
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    guard let characteristic = localCharacteristic else { return }
    while !pendingNotifications.isEmpty {
      let frame = pendingNotifications[0]
      if peripheral.updateValue(frame, for: characteristic, onSubscribedCentrals: nil) {
        pendingNotifications.removeFirst()
      } else {
        break
      }
    }
  }
}

extension BleTransport {
  /// 16 raw bytes of a UUID (tuple types can't be extended, so do it here).
  fileprivate static func uuidBytes(_ uuid: UUID) -> Data {
    var value = uuid.uuid
    return withUnsafeBytes(of: &value) { Data($0) }
  }
}
