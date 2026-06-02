import Flutter
import Foundation

/// Holds the Dart-side event sink for the Pigeon `@EventChannelApi`.
///
/// The transport pushes `TransportEvent`s through this whenever a listener is
/// attached (i.e. the Flutter UI is alive). When Dart is *not* running — the
/// background State-Restoration wake path — `sink` is nil and events are
/// instead persisted + surfaced via a local notification by the transport.
final class TransportEventStreamHandler: StreamTransportEventsStreamHandler {
  private var sink: PigeonEventSink<TransportEvent>?

  var hasListener: Bool { sink != nil }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<TransportEvent>) {
    self.sink = sink
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
  }

  /// Emits an event to Dart on the platform thread. No-op when nobody listens.
  func emit(_ event: TransportEvent) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?.success(event)
    }
  }
}
