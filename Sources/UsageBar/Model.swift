import Foundation

enum Provider: String, CaseIterable, Sendable {
    case claude, codex, grok, opencodeGo

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .grok: "Grok"
        case .opencodeGo: "OpenCode Go"
        }
    }

    // SF Symbols stand in for brand logos (no trademarked artwork in the repo).
    var symbol: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "terminal"
        case .grok: "slash.circle"
        case .opencodeGo: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct UsageWindow: Identifiable, Equatable, Sendable {
    let label: String
    let usedPercent: Double
    let resetsAt: Date?
    var id: String { label }
    var leftPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

struct Snapshot: Equatable, Sendable {
    var plan: String?
    var windows: [UsageWindow]
}

struct Failure: Error, Sendable {
    let message: String
    /// No credentials on this Mac at all (as opposed to a broken or expired login).
    let notSignedIn: Bool
    init(_ message: String, notSignedIn: Bool = false) { self.message = message; self.notSignedIn = notSignedIn }
}

/// What the UI shows for one provider. A failure keeps the last good snapshot ("stale").
struct ProviderState: Sendable {
    var snapshot: Snapshot?
    var error: String?
    var updatedAt: Date?
    var notSignedIn = false
}

/// Providers the menu bar shows: one with no credentials on this Mac is left out instead of showing "!".
func shownProviders(_ states: [Provider: ProviderState]) -> [Provider] {
    Provider.allCases.filter { states[$0]?.notSignedIn != true }
}
