import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var states: [Provider: ProviderState] = [:]
    @Published var refreshing = false
    @Published var showLeft: Bool = UserDefaults.standard.object(forKey: "showLeft") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showLeft, forKey: "showLeft") }
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
                case .success(let snap): s.snapshot = snap; s.error = nil; s.updatedAt = Date()
                case .failure(let f): s.error = f.message
                }
                states[p] = s
            }
        }
        refreshing = false
    }
}
