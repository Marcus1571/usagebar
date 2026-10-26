import Foundation

// READ-ONLY by design: this file never writes a token, a Keychain item or any provider
// config. Rotating refresh tokens are shared with the official CLIs, so a second program
// refreshing them can sign the CLI out. When a login is stale we either wait for the CLI
// to renew it (Claude) or ask the CLI itself to renew it (Grok), never do it ourselves.

// MARK: - helpers

func num(_ any: Any?) -> Double? { (any as? NSNumber)?.doubleValue }

/// ISO-8601 with any number of fractional digits ("…:00.417577+00:00", "…55.093Z").
func parseDate(_ text: String?) -> Date? {
    guard var s = text else { return nil }
    if let r = s.range(of: #"\.\d+"#, options: .regularExpression) {
        let digits = s[r].dropFirst().prefix(3)
        s.replaceSubrange(r, with: "." + digits.padding(toLength: 3, withPad: "0", startingAt: 0))
    }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

func jsonObject(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

enum Http {
    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.httpCookieStorage = nil
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    static func get(_ url: String, _ headers: [String: String]) async throws -> (Int, Data) {
        var r = URLRequest(url: URL(string: url)!)
        r.setValue("usagebar/0.1", forHTTPHeaderField: "User-Agent")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
        do {
            let (d, resp) = try await session.data(for: r)
            return ((resp as? HTTPURLResponse)?.statusCode ?? 0, d)
        } catch {
            throw Failure("Can't reach the network")
        }
    }
}

enum Shell {
    /// Runs a program, returns stdout on exit 0, nil otherwise. Killed after `timeout`.
    static func run(_ exe: String, _ args: [String], timeout: TimeInterval = 20) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                let out = Pipe()
                p.standardOutput = out
                p.standardError = FileHandle.nullDevice
                p.standardInput = FileHandle.nullDevice
                do { try p.run() } catch { cont.resume(returning: nil); return }
                let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
                let data = out.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                killer.cancel()
                cont.resume(returning: p.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil)
            }
        }
    }

    static func findCLI(_ name: String) -> String? {
        let home = NSHomeDirectory()
        let dirs = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "\(home)/.npm-global/bin", "\(home)/.bun/bin"]
        return dirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

actor Throttle {
    private var last = Date.distantPast
    func allow(every seconds: TimeInterval) -> Bool {
        guard Date().timeIntervalSince(last) >= seconds else { return false }
        last = Date()
        return true
    }
}

// MARK: - Claude

enum Claude {
    static let url = "https://api.anthropic.com/api/oauth/usage"
    static let staleMessage = "Claude login is stale: use Claude Code once and it renews itself"

    struct Creds { var token: String; var expiresAt: Date?; var plan: String? }

    static func fetch() async throws -> Snapshot {
        guard let c = await readCreds() else { throw Failure("Not signed in: run `claude` once") }
        if let exp = c.expiresAt, exp < Date() { throw Failure(staleMessage) }
        let (status, data) = try await Http.get(url, ["Authorization": "Bearer \(c.token)", "anthropic-beta": "oauth-2025-04-20"])
        switch status {
        case 200..<300: return try parse(data, plan: c.plan)
        case 401, 403: throw Failure(staleMessage)
        case 429: throw Failure("Rate limited: will retry")
        default: throw Failure("Claude usage returned HTTP \(status)")
        }
    }

    /// Keychain first (that is Claude Code's live login); the file is only a fallback.
    static func readCreds() async -> Creds? {
        if let raw = await Shell.run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
           let c = parseCreds(raw) { return c }
        if let d = FileManager.default.contents(atPath: NSHomeDirectory() + "/.claude/.credentials.json"),
           let c = parseCreds(String(decoding: d, as: UTF8.self)) { return c }
        return nil
    }

    static func parseCreds(_ text: String) -> Creds? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var obj = jsonObject(Data(t.utf8))
        if obj == nil, t.count % 2 == 0, t.allSatisfy(\.isHexDigit) {   // `security -w` prints hex for some items
            var bytes = Data(); var i = t.startIndex
            while i < t.endIndex {
                let n = t.index(i, offsetBy: 2)
                guard let b = UInt8(t[i..<n], radix: 16) else { return nil }
                bytes.append(b); i = n
            }
            obj = jsonObject(bytes)
        }
        guard let oauth = obj?["claudeAiOauth"] as? [String: Any], let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        return Creds(token: token,
                     expiresAt: num(oauth["expiresAt"]).map { Date(timeIntervalSince1970: $0 / 1000) },
                     plan: (oauth["subscriptionType"] as? String).map(prettyPlan))
    }

    static func parse(_ data: Data, plan: String?) throws -> Snapshot {
        guard let root = jsonObject(data) else { throw Failure("Unexpected Claude response") }
        var windows: [UsageWindow] = []
        if let limits = root["limits"] as? [[String: Any]] {
            for l in limits {
                guard let pct = num(l["percent"]) else { continue }
                let label: String
                switch l["kind"] as? String {
                case "session": label = "5-hour session"
                case "weekly_all": label = "Weekly"
                case "weekly_scoped": label = "Weekly · " + (modelName(l["scope"]) ?? "model")
                default: continue
                }
                windows.append(UsageWindow(label: label, usedPercent: pct, resetsAt: parseDate(l["resets_at"] as? String)))
            }
        }
        if windows.isEmpty {   // older response shape
            for (key, label) in [("five_hour", "5-hour session"), ("seven_day", "Weekly"),
                                 ("seven_day_opus", "Weekly · Opus"), ("seven_day_sonnet", "Weekly · Sonnet")] {
                if let w = root[key] as? [String: Any], let pct = num(w["utilization"]) {
                    windows.append(UsageWindow(label: label, usedPercent: pct, resetsAt: parseDate(w["resets_at"] as? String)))
                }
            }
        }
        guard !windows.isEmpty else { throw Failure("This account has no subscription limits") }
        return Snapshot(plan: plan, windows: windows)
    }

    private static func modelName(_ scope: Any?) -> String? {
        guard let s = scope as? [String: Any] else { return nil }
        let m = (s["model"] as? [String: Any]) ?? s
        for k in ["display_name", "name", "id"] { if let v = m[k] as? String, !v.isEmpty { return v } }
        return nil
    }
}

// MARK: - Codex (ChatGPT plans)

enum Codex {
    static let url = "https://chatgpt.com/backend-api/wham/usage"

    static func fetch() async throws -> Snapshot {
        let path = NSHomeDirectory() + "/.codex/auth.json"
        guard let d = FileManager.default.contents(atPath: path),
              let tokens = jsonObject(d)?["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else { throw Failure("Not signed in: run `codex` once") }
        var headers = ["Authorization": "Bearer \(token)"]
        if let id = tokens["account_id"] as? String { headers["ChatGPT-Account-Id"] = id }
        let (status, data) = try await Http.get(url, headers)
        switch status {
        case 200..<300: return try parse(data)
        case 401, 403: throw Failure("Codex login is stale: run `codex` once")
        case 429: throw Failure("Rate limited: will retry")
        default: throw Failure("Codex usage returned HTTP \(status)")
        }
    }

    static func parse(_ data: Data) throws -> Snapshot {
        guard let root = jsonObject(data) else { throw Failure("Unexpected Codex response") }
        var windows: [UsageWindow] = []
        let rl = root["rate_limit"] as? [String: Any]
        for key in ["primary_window", "secondary_window"] {
            guard let w = rl?[key] as? [String: Any], let used = num(w["used_percent"]) else { continue }
            var reset: Date? = num(w["reset_at"]).map { Date(timeIntervalSince1970: $0) }
            if reset == nil, let after = num(w["reset_after_seconds"]) { reset = Date().addingTimeInterval(after) }
            windows.append(UsageWindow(label: windowLabel(Int(num(w["limit_window_seconds"]) ?? 0)), usedPercent: used, resetsAt: reset))
        }
        guard !windows.isEmpty else { throw Failure("This plan has no usage limits") }
        return Snapshot(plan: (root["plan_type"] as? String).map(prettyPlan), windows: windows)
    }

    static func windowLabel(_ seconds: Int) -> String {
        switch seconds {
        case 17_000...19_000: return "5-hour session"
        case 600_000...610_000: return "Weekly"
        case 2_500_000...2_700_000: return "Monthly"
        case 1...: return seconds % 86_400 == 0 ? "\(seconds / 86_400)-day" : "\(max(1, seconds / 3600))-hour"
        default: return "Limit"
        }
    }
}

// MARK: - Grok

enum Grok {
    static let url = "https://cli-chat-proxy.grok.com/v1/billing?format=credits"
    static let throttle = Throttle()

    struct Creds { var token: String; var expiresAt: Date? }

    static func readCreds() -> Creds? {
        guard let d = FileManager.default.contents(atPath: NSHomeDirectory() + "/.grok/auth.json"),
              let root = jsonObject(d) else { return nil }
        for case let entry as [String: Any] in root.values {
            if let key = entry["key"] as? String, !key.isEmpty {
                return Creds(token: key, expiresAt: parseDate(entry["expires_at"] as? String))
            }
        }
        return nil
    }

    static func fetch() async throws -> Snapshot {
        guard var c = readCreds() else { throw Failure("Not signed in: run `grok` once") }
        if (c.expiresAt ?? .distantFuture) < Date().addingTimeInterval(60), await renewViaCLI(), let fresh = readCreds() { c = fresh }
        var (status, data) = try await Http.get(url, ["Authorization": "Bearer \(c.token)"])
        if status == 401, await renewViaCLI(), let fresh = readCreds() {
            (status, data) = try await Http.get(url, ["Authorization": "Bearer \(fresh.token)"])
        }
        switch status {
        case 200..<300: return try parse(data)
        case 401, 403: throw Failure("Grok login is stale: run `grok` once")
        case 429: throw Failure("Rate limited: will retry")
        default: throw Failure("Grok billing returned HTTP \(status)")
        }
    }

    /// Lets the official CLI renew its own login: `grok models` is a harmless call that does it.
    static func renewViaCLI() async -> Bool {
        guard let exe = Shell.findCLI("grok"), await throttle.allow(every: 20 * 60) else { return false }
        return await Shell.run(exe, ["models"], timeout: 45) != nil
    }

    static func parse(_ data: Data) throws -> Snapshot {
        guard let config = jsonObject(data)?["config"] as? [String: Any] else { throw Failure("Unexpected Grok response") }
        let period = config["currentPeriod"] as? [String: Any]
        let end = parseDate(period?["end"] as? String) ?? parseDate(config["billingPeriodEnd"] as? String)
        guard period != nil || end != nil else { throw Failure("This plan has no usage limits") }
        // The API omits zero-valued fields, so a missing percentage means 0% used.
        let used = num(config["creditUsagePercent"]) ?? 0
        let type = (period?["type"] as? String) ?? ""
        let label = type.contains("WEEKLY") ? "Weekly" : type.contains("MONTHLY") ? "Monthly" : type.contains("DAILY") ? "Daily" : "Credits"
        return Snapshot(plan: nil, windows: [UsageWindow(label: label, usedPercent: used, resetsAt: end)])
    }
}

/// "max_5x" -> "Max 5x" (only the first letter of each word, so "5x" is not turned into "5X").
func prettyPlan(_ raw: String) -> String {
    raw.split(whereSeparator: { $0 == "_" || $0 == " " })
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}

func fetch(_ p: Provider) async throws -> Snapshot {
    switch p {
    case .claude: try await Claude.fetch()
    case .codex: try await Codex.fetch()
    case .grok: try await Grok.fetch()
    }
}
