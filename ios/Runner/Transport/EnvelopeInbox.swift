import Foundation

/// App Group shared "inbox" for background-received envelopes.
///
/// During a background BLE wake the Flutter engine isn't running, so inbound
/// envelopes are written here as individual files; Dart drains + deletes them
/// on next launch/resume. Using a shared *directory* (not a shared SQLite file)
/// keeps the drift database single-writer (Dart) and avoids cross-process
/// corruption.
enum SharedContainer {
  /// Must match the App Group capability on the Runner target + provisioning.
  static let appGroupId = "group.com.stonechat"

  /// The inbox directory URL, created if needed. Falls back to the app's own
  /// Application Support directory when the App Group isn't provisioned (e.g.
  /// a free signing team), so the app still runs — only cross-process hand-off
  /// to future extensions would be unavailable.
  static func inboxURL() -> URL? {
    let fm = FileManager.default
    let base: URL
    if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
      base = group
    } else if let support = try? fm.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      base = support
    } else {
      return nil
    }
    let inbox = base.appendingPathComponent("inbox", isDirectory: true)
    do {
      try fm.createDirectory(at: inbox, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    return inbox
  }
}

enum EnvelopeInbox {
  /// Persists one inbound envelope as a uniquely-named `.env` file.
  static func write(_ envelope: Data) {
    guard let inbox = SharedContainer.inboxURL() else { return }
    let file = inbox.appendingPathComponent("\(UUID().uuidString).env")
    try? envelope.write(to: file, options: .atomic)
  }
}
