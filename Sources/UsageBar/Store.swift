import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var states: [Provider: ProviderState] = [:]
    @Published var refreshing = false
    // Settings persist in AppSettings (a bundle-id-independent JSON file), not UserDefaults:
    // see AppSettings.swift for why.
    @Published var showLeft: Bool = AppSettings.object(forKey: "showLeft") as? Bool ?? true {
        didSet { AppSettings.set(showLeft, forKey: "showLeft") }
    }
    @Published var hiddenProviders: Set<Provider> = Set(
        (AppSettings.object(forKey: "hiddenProviders") as? [String] ?? []).compactMap(Provider.init(rawValue:))
    ) {
        didSet { AppSettings.set(hiddenProviders.map(\.rawValue), forKey: "hiddenProviders") }
    }
    @Published var labelStyle: Int = AppSettings.object(forKey: "labelStyle") as? Int ?? 4 {
        didSet { AppSettings.set(labelStyle, forKey: "labelStyle") }
    }
    @Published var refreshInterval: TimeInterval = AppSettings.object(forKey: "refreshInterval") as? TimeInterval ?? 300 {
        didSet { AppSettings.set(refreshInterval, forKey: "refreshInterval") }
    }

    private var lastRefresh = Date.distantPast

    var lastUpdate: Date? { states.values.compactMap(\.updatedAt).max() }

    /// `force` bypasses the 60 s minimum so the refresh button always works.
    func refresh(force: Bool = false) async {
        guard !refreshing, force || Date().timeIntervalSince(lastRefresh) >= 60 else { return }
        refreshing = true
        lastRefresh = Date()
        await withTaskGroup(of: (Provider, Result<Snapshot, Failure>).self) { group in
            for p in Provider.allCases {
                group.addTask {
                    do { return (p, .success(try await fetch(p))) }
                    catch let f as Failure { return (p, .failure(f)) }
                    catch { return (p, .failure(Failure("Unexpected error"))) }
                }
            }
            for await (p, result) in group {
                var s = states[p] ?? ProviderState()
                switch result {
                case .success(let snap): s.snapshot = snap; s.error = nil; s.notSignedIn = false; s.updatedAt = Date()
                case .failure(let f):
                    s.error = f.message
                    s.notSignedIn = f.notSignedIn
                    if f.notSignedIn { s.snapshot = nil }   // signed out: old numbers no longer apply
                }
                states[p] = s
            }
        }
        refreshing = false
    }
}
