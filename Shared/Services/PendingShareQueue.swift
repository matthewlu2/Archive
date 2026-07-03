import Foundation

/// URLs saved by the Share Extension that the main app should ingest on
/// next launch (e.g. shares that arrived while signed out).
///
/// Backed by App Group defaults when the App Groups capability is set up;
/// falls back to standard defaults so the paste-to-save path still works.
struct PendingShareQueue {
    private static let key = "pendingShareURLs"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: SupabaseConfig.appGroupID) ?? .standard
    }

    func enqueue(_ url: URL) {
        var urls = defaults.stringArray(forKey: Self.key) ?? []
        guard !urls.contains(url.absoluteString) else { return }
        urls.append(url.absoluteString)
        defaults.set(urls, forKey: Self.key)
    }

    /// Removes and returns all pending URLs.
    func drain() -> [URL] {
        let urls = (defaults.stringArray(forKey: Self.key) ?? []).compactMap(URL.init(string:))
        defaults.removeObject(forKey: Self.key)
        return urls
    }

    var isEmpty: Bool {
        (defaults.stringArray(forKey: Self.key) ?? []).isEmpty
    }
}
