import Foundation

/// The app's settings, held in `~/Library/Application Support/UsageBar/settings.json` — keyed to
/// the app's own folder, not to the bundle identifier. UserDefaults are keyed to the bundle id,
/// so 0.6.0's id change (`local.usagebar` → `com.usagebar.app`) read a fresh domain and silently
/// reset every setting, including Left/Used, on first launch of the new id; a file in a fixed
/// folder cannot have that happen to it again.
///
/// On a first launch with no settings file, values are imported once from the old store: the
/// standard UserDefaults domain (whatever the current bundle id is), with any key it lacks
/// filled from the pre-0.6.0 `local.usagebar` domain. The written file is the done-flag — the
/// legacy plists are left untouched and never read again once the file exists.
enum AppSettings {
    private static let keys = ["showLeft", "hiddenProviders", "labelStyle", "refreshInterval"]

    /// Overridden by the self-test to point at a temporary file.
    static var fileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("UsageBar/settings.json")

    /// Import sources; overridden by the self-test to use throwaway suites.
    static var currentDomain: UserDefaults = .standard
    static var legacyDomain: UserDefaults? = UserDefaults(suiteName: "local.usagebar")

    /// Cached settings so several initial reads share one file access; the self-test clears it
    /// to force reads back from disk.
    static var cache: [String: Any]?

    /// All settings. The first call imports from the old domains if no file exists yet.
    static func load() -> [String: Any] {
        if let cache { return cache }
        var values: [String: Any]
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // An existing but unreadable file imports nothing: better plain defaults than
            // resurrecting stale legacy values over the user's newer choices.
            values = (try? Data(contentsOf: fileURL))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        } else {
            values = [:]
            for key in keys {
                if let v = currentDomain.object(forKey: key) { values[key] = v }
                else if let v = legacyDomain?.object(forKey: key) { values[key] = v }
            }
            write(values)
        }
        cache = values
        return values
    }

    static func object(forKey key: String) -> Any? { load()[key] }

    static func set(_ value: Any, forKey key: String) {
        var values = load()
        values[key] = value
        write(values)
        cache = values
    }

    private static func write(_ values: [String: Any]) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        guard let data = try? JSONSerialization.data(withJSONObject: values,
                                                     options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
