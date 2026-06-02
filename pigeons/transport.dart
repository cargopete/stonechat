// Pigeon contract for the native Core Bluetooth transport layer.
//
// Regenerate after editing with:
//   dart run pigeon --input pigeons/transport.dart
//
// The native (Swift) side owns the BLE transport entirely: discovery,
// connection, fragmentation/reassembly, persistence of inbound ciphertext and
// firing local notifications during background State Restoration. Dart never
// runs on a BLE wake, so this contract is deliberately one-shot
// command (HostApi) + streaming event (EventChannelApi) only.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/transport/transport_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/Transport/TransportApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'stonechat',
  ),
)

/// Mirror of `CBManagerState`.
enum BleAdapterState {
  unknown,
  resetting,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
}

/// Lifecycle of a single peer link.
enum PeerConnectionState { disconnected, connecting, connected, disconnecting }

/// One-time configuration handed to the native transport on startup.
class TransportConfig {
  TransportConfig({
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.displayName,
    required this.centralRestoreIdentifier,
    required this.peripheralRestoreIdentifier,
  });

  /// Custom 128-bit GATT service UUID advertised + scanned for.
  final String serviceUuid;

  /// Single bidirectional write/notify characteristic UUID.
  final String characteristicUuid;

  /// Short name surfaced to the peer in the hello/identity handshake.
  final String displayName;

  /// `CBCentralManagerOptionRestoreIdentifierKey` value.
  final String centralRestoreIdentifier;

  /// `CBPeripheralManagerOptionRestoreIdentifierKey` value.
  final String peripheralRestoreIdentifier;
}

/// A peer surfaced by a scan match.
class PeerInfo {
  PeerInfo({required this.peerId, this.name, required this.rssi});

  /// Stable opaque identifier for the discovered peripheral (CBPeripheral
  /// identifier UUID string). Not the cryptographic identity — that arrives
  /// inside the first signed envelope.
  final String peerId;
  final String? name;
  final int rssi;
}

// --- Event channel union -----------------------------------------------------

sealed class TransportEvent {}

class AdapterStateEvent extends TransportEvent {
  AdapterStateEvent(this.state);
  final BleAdapterState state;
}

class PeerDiscoveredEvent extends TransportEvent {
  PeerDiscoveredEvent(this.peer);
  final PeerInfo peer;
}

class PeerConnectionEvent extends TransportEvent {
  PeerConnectionEvent(this.peerId, this.state);
  final String peerId;
  final PeerConnectionState state;
}

/// A fully reassembled inbound envelope (still signed + boxed — Dart decrypts).
class EnvelopeReceivedEvent extends TransportEvent {
  EnvelopeReceivedEvent(this.peerId, this.envelope, this.receivedAtMs);
  final String peerId;
  final Uint8List envelope;
  final int receivedAtMs;
}

// --- APIs --------------------------------------------------------------------

@HostApi()
abstract class TransportHostApi {
  /// Initialise both CB managers with restore identifiers. Idempotent.
  @async
  void configure(TransportConfig config);

  void startAdvertising();
  void stopAdvertising();

  void startScanning();
  void stopScanning();

  @async
  void connect(String peerId);
  void disconnect(String peerId);

  /// Fragments [envelope] (START/CONTINUE/END) and writes it to [peerId].
  /// Returns true if the write was dispatched (not an end-to-end ACK — that is
  /// an application-layer envelope handled in Dart).
  @async
  bool sendEnvelope(String peerId, Uint8List envelope);

  List<String> connectedPeers();
}

@EventChannelApi()
abstract class TransportStreamApi {
  TransportEvent streamTransportEvents();
}
