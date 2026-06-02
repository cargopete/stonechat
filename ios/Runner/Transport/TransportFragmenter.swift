import Foundation

/// Transport-level fragmentation that sits *below* the application envelope.
///
/// ATT MTU caps a single GATT write (commonly 185 bytes on older devices, up to
/// 247/512 when negotiated), so every outbound envelope is split into frames
/// carrying a per-message id + index + count. The receiver reassembles by id.
/// This is the START/CONTINUE/END scheme described in the architecture brief,
/// generalised to an explicit (index, count) so out-of-order delivery and
/// interleaved messages reassemble correctly.
///
/// Frame layout (big-endian):
///   [0]      kind: UInt8        (0 = whole, 1 = start, 2 = continue, 3 = end)
///   [1..16]  messageId: 16 bytes
///   [17..20] index: UInt32
///   [21..24] count: UInt32
///   [25...]  payload chunk
enum FragmentKind: UInt8 {
  case whole = 0
  case start = 1
  case cont = 2
  case end = 3
}

enum TransportFragmenter {
  static let headerSize = 1 + 16 + 4 + 4

  /// Splits [data] into wire frames no larger than [maxFrameSize].
  /// [messageId] must be 16 bytes; callers typically pass `UUID` bytes.
  static func split(_ data: Data, messageId: Data, maxFrameSize: Int) -> [Data] {
    precondition(messageId.count == 16, "messageId must be 16 bytes")
    let maxPayload = max(1, maxFrameSize - headerSize)
    var chunks: [Data] = []
    var offset = 0
    while offset < data.count {
      let end = min(offset + maxPayload, data.count)
      chunks.append(data.subdata(in: offset..<end))
      offset = end
    }
    if chunks.isEmpty { chunks = [Data()] }

    let count = UInt32(chunks.count)
    return chunks.enumerated().map { index, chunk in
      let kind: FragmentKind
      if count == 1 {
        kind = .whole
      } else if index == 0 {
        kind = .start
      } else if index == chunks.count - 1 {
        kind = .end
      } else {
        kind = .cont
      }
      return frame(kind: kind, messageId: messageId, index: UInt32(index), count: count, payload: chunk)
    }
  }

  private static func frame(
    kind: FragmentKind, messageId: Data, index: UInt32, count: UInt32, payload: Data
  ) -> Data {
    var out = Data(capacity: headerSize + payload.count)
    out.append(kind.rawValue)
    out.append(messageId)
    out.append(bigEndian: index)
    out.append(bigEndian: count)
    out.append(payload)
    return out
  }
}

/// Stateful reassembler. One instance per transport; keyed internally by
/// message id so concurrent inbound messages don't collide.
final class FragmentReassembler {
  private struct Partial {
    let count: Int
    var chunks: [Int: Data] = [:]
  }

  private var partials: [Data: Partial] = [:]

  /// Feeds one inbound frame. Returns the complete payload when the final
  /// fragment for its message id arrives, otherwise nil.
  func ingest(_ frame: Data) -> Data? {
    guard frame.count >= TransportFragmenter.headerSize else { return nil }
    let bytes = [UInt8](frame)
    guard let kind = FragmentKind(rawValue: bytes[0]) else { return nil }

    let messageId = frame.subdata(in: 1..<17)
    let index = Int(frame.readBigEndianUInt32(at: 17))
    let count = Int(frame.readBigEndianUInt32(at: 21))
    let payload = frame.subdata(in: TransportFragmenter.headerSize..<frame.count)

    if kind == .whole {
      return payload
    }

    var partial = partials[messageId] ?? Partial(count: count)
    partial.chunks[index] = payload
    partials[messageId] = partial

    if partial.chunks.count == partial.count {
      partials.removeValue(forKey: messageId)
      var assembled = Data()
      for i in 0..<partial.count {
        guard let chunk = partial.chunks[i] else { return nil }
        assembled.append(chunk)
      }
      return assembled
    }
    return nil
  }
}

private extension Data {
  mutating func append(bigEndian value: UInt32) {
    append(UInt8((value >> 24) & 0xFF))
    append(UInt8((value >> 16) & 0xFF))
    append(UInt8((value >> 8) & 0xFF))
    append(UInt8(value & 0xFF))
  }

  func readBigEndianUInt32(at offset: Int) -> UInt32 {
    let b = [UInt8](self[startIndex + offset..<startIndex + offset + 4])
    return (UInt32(b[0]) << 24) | (UInt32(b[1]) << 16) | (UInt32(b[2]) << 8) | UInt32(b[3])
  }
}
