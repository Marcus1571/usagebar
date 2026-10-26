import Foundation

enum Provider: String, CaseIterable, Sendable {
    case claude, codex, grok

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .grok: "Grok"
        }
    }

    // SF Symbols stand in for brand logos (no trademarked artwork in the repo).
    var symbol: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "terminal"
        case .grok: "slash.circle"
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
    init(_ message: String) { self.message = message }
}

/// What the UI shows for one provider. A failure keeps the last good snapshot ("stale").
struct ProviderState: Sendable {
    var snapshot: Snapshot?
    var error: String?
    var updatedAt: Date?
}
