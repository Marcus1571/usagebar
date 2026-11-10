import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var states: [Provider: ProviderState] = [:]
    @Published var refreshing = false
    @Published var showLeft: Bool = UserDefaults.standard.object(forKey: "showLeft") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showLeft, forKey: "showLeft") }
    }
    @Published var hiddenProviders: Set<Provider> = Set(
        (UserDefaults.standard.object(forKey: "hiddenProviders") as? [String] ?? []).compactMap(Provider.init(rawValue:))
    ) {
        didSet { UserDefaults.standard.set(hiddenProviders.map(\.rawValue), forKey: "hiddenProviders") }
    }
    @Published var labelStyle: Int = UserDefaults.standard.object(forKey: "labelStyle") as? Int ?? 4 {
        didSet { UserDefaults.standard.set(labelStyle, forKey: "labelStyle") }
    }
    @Published var refreshInterval: TimeInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? TimeInterval ?? 300 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
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
