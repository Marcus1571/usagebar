import SwiftUI
import AppKit

// MARK: - formatting

func resetText(_ date: Date?, now: Date = Date()) -> String {
    guard let date else { return "No reset time" }
    let s = Int(date.timeIntervalSince(now))
    if s <= 0 { return "Resetting…" }
    let d = s / 86_400, h = (s % 86_400) / 3600, m = (s % 3600) / 60
    if d > 0 { return "Resets in \(d)d \(h)h" }
    if h > 0 { return "Resets in \(h)h \(m)m" }
    return "Resets in \(max(m, 1))m"
}

func agoText(_ date: Date?, now: Date = Date()) -> String {
    guard let date else { return "Not updated yet" }
    let s = Int(now.timeIntervalSince(date))
    if s < 10 { return "Updated just now" }
    if s < 60 { return "Updated \(s) s ago" }
    return "Updated \(s / 60) min ago"
}

/// Colour follows what is LEFT, whichever way the numbers are displayed.
func limitColor(left: Double) -> Color { left > 40 ? .green : left > 20 ? .orange : .red }

// MARK: - menu bar label (rendered to an image so it can stack two numbers)

struct LabelView: View {
    let states: [Provider: ProviderState]
    let showLeft: Bool
    let dark: Bool
    var style = 4   // 0 none, 1 outline, 2 outline + dividers, 3 filled pill, 4 filled + outline

    var body: some View {
        let base: Color = dark ? .white : .black
        let framed = style > 0
        HStack(spacing: style == 2 ? 0 : 9) {
            ForEach(Array(Provider.allCases.enumerated()), id: \.offset) { i, p in
                if style == 2 && i > 0 { Rectangle().fill(base.opacity(0.3)).frame(width: 1, height: 14).padding(.horizontal, 8) }
                item(p)
            }
        }
        .fixedSize()
        .padding(.horizontal, framed ? 8 : 2)
        .frame(height: framed ? 20 : 22)
        .background { if style >= 3 { RoundedRectangle(cornerRadius: 6).fill(base.opacity(0.14)) } }
        .overlay { if style == 1 || style == 2 || style == 4 { RoundedRectangle(cornerRadius: 6).stroke(base.opacity(0.45), lineWidth: 1) } }
        .frame(height: 22)
    }

    private func item(_ p: Provider) -> some View {
        let state = states[p]
        let windows = Array((state?.snapshot?.windows ?? []).prefix(2))
        let base: Color = dark ? .white : .black
        return HStack(spacing: 3) {
            Image(systemName: p.symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(base)
            if windows.isEmpty {
                Text(state?.error != nil ? "!" : "–")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).fixedSize().foregroundStyle(state?.error != nil ? .orange : base.opacity(0.6))
            } else {
                VStack(alignment: .trailing, spacing: -1) {
                    ForEach(windows) { w in
                        let value = showLeft ? w.leftPercent : w.usedPercent
                        Text("\(Int(value.rounded()))%")
                            .font(.system(size: windows.count == 1 ? 12 : 9.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .fixedSize()
                            .foregroundStyle(w.leftPercent <= 20 ? Color.red : w.leftPercent <= 40 ? Color.orange : base)
                    }
                }
                .opacity(state?.error != nil ? 0.55 : 1)   // dimmed = stale
            }
        }
    }
}

// MARK: - popover

struct PopoverView: View {
    @ObservedObject var store: Store
    var onQuit: () -> Void = {}
    var forImage = false   // ImageRenderer cannot draw native controls; docs screenshots use look-alikes

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Usage").font(.title3.bold())
                Spacer()
                if forImage {
                    HStack(spacing: 0) {
                        ForEach([true, false], id: \.self) { left in
                            Text(left ? "Left" : "Used").font(.caption)
                                .frame(width: 58, height: 20)
                                .background(RoundedRectangle(cornerRadius: 5).fill(store.showLeft == left ? Color.primary.opacity(0.16) : .clear))
                        }
                    }
                    .padding(2).background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.08)))
                } else {
                    Picker("", selection: $store.showLeft) {
                        Text("Left").tag(true)
                        Text("Used").tag(false)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 120)
                }
            }
            ForEach(Provider.allCases, id: \.self) { card($0) }
            footer
        }
        .padding(14)
        .frame(width: 350)
    }

    private func card(_ p: Provider) -> some View {
        let state = store.states[p]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: p.symbol).font(.system(size: 15, weight: .medium))
                Text(p.title).font(.headline)
                Spacer()
                if let plan = state?.snapshot?.plan {
                    Text(plan).font(.caption2.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                }
            }
            if let snap = state?.snapshot {
                ForEach(snap.windows) { windowRow($0) }
                if let e = state?.error {
                    Label(e, systemImage: "exclamationmark.triangle").font(.caption2).foregroundStyle(.orange)
                }
            } else if let e = state?.error {
                Label(e, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            } else {
                HStack { ProgressView().controlSize(.small); Text("Loading…").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
    }

    private func windowRow(_ w: UsageWindow) -> some View {
        let value = store.showLeft ? w.leftPercent : w.usedPercent
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(w.label).font(.subheadline)
                Spacer()
                Text("\(Int(value.rounded()))%").font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(w.leftPercent <= 20 ? .red : w.leftPercent <= 40 ? .orange : .primary)
                Text(store.showLeft ? "left" : "used").font(.caption).foregroundStyle(.secondary)
            }
            Bar(fraction: value / 100, color: limitColor(left: w.leftPercent))
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.system(size: 9))
                Text(resetText(w.resetsAt)).font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            let failing = store.states.values.contains { $0.error != nil }
            Circle().fill(failing ? Color.orange : Color.green).frame(width: 8, height: 8)
            TimelineView(.periodic(from: .now, by: 15)) { ctx in
                Text(agoText(store.lastUpdate, now: ctx.date)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if forImage {
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                Image(systemName: "power").foregroundStyle(.secondary)
            } else {
                Button { Task { await store.refresh(force: true) } } label: {
                    if store.refreshing { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless).help("Refresh now")
                Button(action: onQuit) { Image(systemName: "power") }
                    .buttonStyle(.borderless).help("Quit UsageBar")
            }
        }
        .padding(.horizontal, 4)
    }
}

struct Bar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color).frame(width: max(4, g.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - rendering

@MainActor
func renderLabel(states: [Provider: ProviderState], showLeft: Bool, dark: Bool) -> NSImage? {
    let r = ImageRenderer(content: LabelView(states: states, showLeft: showLeft, dark: dark))
    r.scale = NSScreen.main?.backingScaleFactor ?? 2
    guard let cg = r.cgImage else { return nil }
    let img = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / r.scale, height: CGFloat(cg.height) / r.scale))
    img.isTemplate = false
    return img
}
