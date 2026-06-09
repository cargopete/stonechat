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

  /// The most recent adapter-state event. Core Bluetooth reports the radio's
  /// state once, at launch — *before* the Dart side subscribes — so without
  /// caching it the first listener never learns the adapter is powered on and
  /// the UI is stuck on "Starting Bluetooth…" forever. We replay it on listen.
  private var lastAdapterState: AdapterStateEvent?

  var hasListener: Bool { sink != nil }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<TransportEvent>) {
    self.sink = sink
    // Replay the latest adapter state to the newly-attached listener.
    if let last = lastAdapterState {
      DispatchQueue.main.async { sink.success(last) }
    }
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
  }

  /// Emits an event to Dart on the platform thread. Adapter-state events are
  /// cached (and replayed on the next `onListen`) so a late subscriber still
  /// learns the current radio state; other events are dropped if nobody listens.
  func emit(_ event: TransportEvent) {
    if let adapter = event as? AdapterStateEvent {
      lastAdapterState = adapter
    }
    DispatchQueue.main.async { [weak self] in
      self?.sink?.success(event)
    }
  }
}
