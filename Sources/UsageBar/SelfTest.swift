import Foundation

// Parser checks against the response shapes the real endpoints returned on 2026-10-23
// (identity fields removed). Run: UsageBar --selftest

func selfTest() {
    var failures = 0
    func check(_ cond: Bool, _ what: String) {
        print(cond ? "ok   " : "FAIL ", what)
        if !cond { failures += 1 }
    }

    // dates: microsecond fractions and Z/offset forms
    check(parseDate("2026-10-23T13:40:00.417577+00:00") == Date(timeIntervalSince1970: 1_792_762_800.417), "date: microseconds + offset")
    check(parseDate("2026-10-23T18:44:46.855093Z") != nil, "date: microseconds + Z")
    check(parseDate("2026-10-23T18:44:46Z") != nil, "date: no fraction")
    check(parseDate("nope") == nil, "date: garbage is nil")

    // Claude: `limits` array
    let claude = #"""
    {"five_hour":{"utilization":52.0,"resets_at":"2026-10-23T13:40:00.417577+00:00"},
     "seven_day":{"utilization":54.0,"resets_at":"2026-10-23T22:00:00.417601+00:00"},
     "limits":[{"kind":"session","percent":52,"resets_at":"2026-10-23T13:40:00.417577+00:00","scope":null},
               {"kind":"weekly_all","percent":54,"resets_at":"2026-10-23T22:00:00.417601+00:00","scope":null},
               {"kind":"weekly_scoped","percent":10,"resets_at":"2026-10-23T22:00:00+00:00","scope":{"model":{"display_name":"Sonnet"}}},
               {"kind":"something_new","percent":1}]}
    """#
    if let s = try? Claude.parse(Data(claude.utf8), plan: "Pro") {
        check(s.windows.map(\.label) == ["5-hour session", "Weekly", "Weekly · Sonnet"], "claude: labels, unknown kind skipped")
        check(s.windows[0].usedPercent == 52 && s.windows[0].leftPercent == 48, "claude: used/left")
        check(s.plan == "Pro", "claude: plan passed through")
    } else { check(false, "claude: parses limits") }

    // Claude: legacy keys when `limits` is absent
    let legacy = #"{"five_hour":{"utilization":10.5,"resets_at":"2026-10-23T13:40:00Z"},"seven_day":{"utilization":20,"resets_at":null}}"#
    check((try? Claude.parse(Data(legacy.utf8), plan: nil))?.windows.count == 2, "claude: legacy five_hour/seven_day")
    check((try? Claude.parse(Data("{}".utf8), plan: nil)) == nil, "claude: empty response is an error")

    // Claude credentials: plain JSON and hex-encoded JSON
    let creds = #"{"claudeAiOauth":{"accessToken":"tok","expiresAt":1792762800000,"subscriptionType":"max_5x"}}"#
    check(Claude.parseCreds(creds)?.token == "tok", "claude creds: json")
    check(Claude.parseCreds(creds)?.plan == "Max 5x", "claude creds: plan prettified")
    check(Claude.parseCreds(Data(creds.utf8).map { String(format: "%02x", $0) }.joined())?.token == "tok", "claude creds: hex")
    check(Claude.parseCreds("not json") == nil, "claude creds: garbage is nil")

    // Codex: a Go plan has ONE 30-day window and no secondary
    let codex = #"{"plan_type":"go","rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":2592000,"reset_after_seconds":2592000,"reset_at":1795351457},"secondary_window":null}}"#
    if let s = try? Codex.parse(Data(codex.utf8)) {
        check(s.windows.count == 1 && s.windows[0].label == "Monthly", "codex: single monthly window")
        check(s.plan == "Go", "codex: plan")
        check(s.windows[0].resetsAt == Date(timeIntervalSince1970: 1_795_351_457), "codex: reset_at epoch")
    } else { check(false, "codex: parses") }
    check(Codex.windowLabel(18_000) == "5-hour session" && Codex.windowLabel(604_800) == "Weekly", "codex: 5h and weekly labels")
    check(Codex.windowLabel(172_800) == "2-day", "codex: odd window label")

    // Grok: omitted percent means 0, weekly label from the period type
    let grok = #"{"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","end":"2026-10-28T23:35:21.057339+00:00"},"creditUsagePercent":4.0}}"#
    if let s = try? Grok.parse(Data(grok.utf8)) {
        check(s.windows[0].label == "Weekly" && s.windows[0].usedPercent == 4, "grok: weekly 4%")
    } else { check(false, "grok: parses") }
    let grokZero = #"{"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","end":"2026-10-28T23:35:21Z"}}}"#
    check((try? Grok.parse(Data(grokZero.utf8)))?.windows[0].usedPercent == 0, "grok: omitted percent = 0")
    check((try? Grok.parse(Data("{}".utf8))) == nil, "grok: empty response is an error")

    // OpenCode Go: rolling / weekly / monthly percentages
    let go = #"{"usage":{"rolling":{"status":"ok","percent":0,"resetsAt":"2026-11-01T22:49:10.835Z"},"weekly":{"status":"ok","percent":12,"resetsAt":"2026-11-02T00:00:00.000Z"},"monthly":{"status":"ok","percent":1,"resetsAt":"2026-11-11T14:26:14.000Z"}}}"#
    if let s = try? OpenCodeGo.parse(Data(go.utf8)) {
        check(s.windows.map(\.label) == ["5-hour session", "Weekly", "Monthly"], "opencode go: three windows in order")
        check(s.windows[1].usedPercent == 12 && s.windows[1].resetsAt != nil, "opencode go: weekly 12% with reset")
    } else { check(false, "opencode go: parses") }
    check((try? OpenCodeGo.parse(Data("{}".utf8))) == nil, "opencode go: empty response is an error")

    // Copilot (free plan, 2026-11-09): premium has no entitlement and is skipped; monthly reset date
    let copilot = #"{"access_type_sku":"free_limited_copilot","copilot_plan":"individual","quota_reset_date_utc":"2026-12-01T00:00:00.000Z","quota_snapshots":{"chat":{"entitlement":200,"percent_remaining":87.5,"remaining":175,"unlimited":false},"completions":{"entitlement":2000,"percent_remaining":100.0,"remaining":2000,"unlimited":false},"premium_interactions":{"entitlement":0,"percent_remaining":0.0,"remaining":0,"unlimited":false}}}"#
    if let s = try? Copilot.parse(Data(copilot.utf8)) {
        check(s.windows.map(\.label) == ["Chat", "Completions"], "copilot: zero-entitlement premium skipped")
        check(s.windows[0].usedPercent == 12.5 && s.windows[0].resetsAt != nil, "copilot: chat 12.5% used, reset date")
        check(s.plan == "Free", "copilot: free plan name")
    } else { check(false, "copilot: parses") }
    let copilotPro = #"{"copilot_plan":"individual_pro","quota_snapshots":{"chat":{"entitlement":0,"percent_remaining":100,"unlimited":true},"premium_interactions":{"entitlement":300,"percent_remaining":40,"unlimited":false}}}"#
    check((try? Copilot.parse(Data(copilotPro.utf8)))?.windows.map(\.label) == ["Premium requests"], "copilot: unlimited chat skipped, premium shown")
    check((try? Copilot.parse(Data("{}".utf8))) == nil, "copilot: empty response is an error")

    // menu bar: a provider with no credentials is left out; a real error still shows
    var st: [Provider: ProviderState] = [:]
    st[.opencodeGo] = ProviderState(error: "Not signed in", notSignedIn: true)
    st[.grok] = ProviderState(error: "Grok billing returned HTTP 500")
    check(shownProviders(st) == [.claude, .codex, .grok, .copilot], "label: not-signed-in provider hidden, failing one kept")
    check(labelKey(states: st, showLeft: true).split(separator: "|", omittingEmptySubsequences: false).count == 4, "label key: hidden provider not counted")

    // menu bar: a provider the user hid in the popover's gear menu is left out too
    check(shownProviders(st, hidden: [.grok]) == [.claude, .codex, .copilot], "label: manually hidden provider left out")
    check(labelKey(states: st, showLeft: true, hidden: [.grok]).split(separator: "|", omittingEmptySubsequences: false).count == 3,
          "label key: membership changes with the hidden set")

    // formatting
    let now = Date(timeIntervalSince1970: 1_000_000)
    check(resetText(now.addingTimeInterval(2 * 3600 + 10 * 60 + 5), now: now) == "Resets in 2h 10m", "format: hours")
    check(resetText(now.addingTimeInterval(3 * 86_400 + 4 * 3600), now: now) == "Resets in 3d 4h", "format: days")
    check(resetText(now.addingTimeInterval(20), now: now) == "Resets in 1m", "format: under a minute")
    check(resetText(now.addingTimeInterval(-5), now: now) == "Resetting…", "format: past")

    print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
    exit(failures == 0 ? 0 : 1)
}
