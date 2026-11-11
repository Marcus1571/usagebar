import SwiftUI

/// The Settings window, opened from the popover's gear button. Everything here is live: the
/// preview is the real label component drawn with the current data, so style choices are honest.
struct SettingsView: View {
    @ObservedObject var store: Store
    var onCheckForUpdates: (() -> Void)? = nil   // present only in packaged builds (Sparkle)

    private var visibleCount: Int {
        shownProviders(store.states, hidden: store.hiddenProviders).count
    }

    var body: some View {
        Form {
            Section("Menu bar") {
                Picker("Numbers", selection: $store.showLeft) {
                    Text("Left").tag(true)
                    Text("Used").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden()

                Picker("Style", selection: $store.labelStyle) {
                    Text("Plain").tag(0)
                    Text("Outline").tag(1)
                    Text("Outline with dividers").tag(2)
                    Text("Pill").tag(3)
                    Text("Pill with outline").tag(4)
                }
                LabelView(states: store.states, showLeft: store.showLeft, hidden: store.hiddenProviders, dark: false, style: store.labelStyle)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
            }
            Section("Providers") {
                ForEach(Provider.allCases, id: \.self) { p in
                    Toggle(isOn: providerBinding(p)) {
                        HStack(spacing: 6) {
                            Image(systemName: p.symbol).font(.system(size: 12))
                            Text(p.title)
                            if store.states[p]?.notSignedIn == true {
                                Text("Not signed in").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(store.hiddenProviders.contains(p) == false && visibleCount == 1)   // never blank the menu bar
                }
            }
            Section("Refresh") {
                Picker("Fetch new data every", selection: minutes) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
            }
            if let onCheckForUpdates {
                Section("Updates") {
                    Button("Check for Updates…") { onCheckForUpdates() }
                    Text("New versions are also checked automatically at startup and once a week, and install without asking.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }

    /// `true` = the provider is shown; turning it off inserts it into the hidden set.
    private func providerBinding(_ p: Provider) -> Binding<Bool> {
        Binding(
            get: { !store.hiddenProviders.contains(p) },
            set: { shown in
                if shown {
                    store.hiddenProviders.remove(p)
                } else {
                    guard visibleCount > 1 else { return }
                    store.hiddenProviders.insert(p)
                }
            }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { Int(store.refreshInterval / 60) },
            set: { store.refreshInterval = TimeInterval($0 * 60) }
        )
    }
}

/// The About window, opened from the popover's ⓘ button — the standard macOS mini page: logo,
/// name and version, author, license, project links.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            if let icon = Bundle.main.image(forResource: "AppIcon") {
                Image(nsImage: icon).resizable().scaledToFit().frame(width: 72, height: 72)
            } else {
                Image(systemName: "chart.bar.fill").font(.system(size: 34)).foregroundStyle(.secondary)
                    .frame(width: 72, height: 72)   // bare dev run: no bundle icon to show
            }
            Text("UsageBar").font(.title2.bold())
            Text(versionLine).font(.caption).foregroundStyle(.secondary)
            Text("How much of your Claude, ChatGPT (Codex), Grok, OpenCode Go and GitHub Copilot quota is left, at a glance — read-only, and credentials go only to each provider's own host.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Divider()
            Text("by Marco Dal Moro").font(.caption)
            Text("Released under the MIT License.").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/Marcus1571/usagebar")!)
                Link("License", destination: URL(string: "https://github.com/Marcus1571/usagebar/blob/main/LICENSE")!)
            }
            .font(.caption)
        }
        .padding(20).frame(width: 300)
    }

    private var versionLine: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String { return "Version \(v)" }
        return "Development build"
    }
}
