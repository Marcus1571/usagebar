import SwiftUI
import AppKit
import Combine

// UsageBar: Claude / Codex / Grok limits in the macOS menu bar. Read-only.
//   UsageBar --dump          fetch once and print (no UI)
//   UsageBar --selftest      run the parser checks
//   UsageBar --render DIR    write label + popover PNGs with live data (no UI)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    var item: NSStatusItem!
    let popover = NSPopover()
    var cancellables = Set<AnyCancellable>()
    var appearanceObserver: NSKeyValueObservation?
    var timer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)

        popover.behavior = .transient
        let host = NSHostingController(rootView: PopoverView(store: store, onQuit: { NSApp.terminate(nil) }))
        host.sizingOptions = .preferredContentSize   // popover follows the SwiftUI content height
        popover.contentViewController = host

        store.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.updateLabel() } }.store(in: &cancellables)
        appearanceObserver = item.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateLabel() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.store.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.store.refresh() }
        }
        updateLabel()
        Task { await store.refresh(force: true) }
        if CommandLine.arguments.contains("--open") {   // handy for screenshots
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.toggle() }
        }
    }

    func updateLabel() {
        let dark = (item.button?.effectiveAppearance ?? NSApp.effectiveAppearance).bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        item.button?.image = renderLabel(states: store.states, showLeft: store.showLeft, dark: dark)
    }

    @objc func toggle() {
        if popover.isShown { popover.performClose(nil); return }
        guard let b = item.button else { return }
        if let v = popover.contentViewController?.view { popover.contentSize = v.fittingSize }
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { await store.refresh() }
    }
}

@MainActor
func savePNG(_ view: some View, _ name: String, _ dir: String) {
    let r = ImageRenderer(content: view)
    r.scale = 2
    guard let cg = r.cgImage else { print("render failed: \(name)"); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    print("wrote \(dir)/\(name).png")
}

/// Draws the actual hosted popover (native segmented control and buttons included) in-process.
@MainActor
func snapshotPopover(store: Store, dark: Bool, to path: String) {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: PopoverView(store: store))
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    let win = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    win.appearance = host.appearance
    win.contentView = host
    win.setFrameOrigin(NSPoint(x: -20_000, y: 0))   // far off-screen: drawn for real, never visible
    win.orderFrontRegardless()
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.6))   // let SwiftUI paint text and controls
    host.display()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { print("snapshot failed"); return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    win.orderOut(nil)
    print("wrote \(path)")
}

let args = CommandLine.arguments

if args.contains("--selftest") {
    selfTest()
} else if args.contains("--dump") || args.contains("--render") {
    let outDir = args.firstIndex(of: "--render").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    Task { @MainActor in
        let store = Store()
        await store.refresh(force: true)
        for p in Provider.allCases {
            let s = store.states[p]
            print("== \(p.title)\(s?.snapshot?.plan.map { " (\($0))" } ?? "")")
            for w in s?.snapshot?.windows ?? [] {
                print(String(format: "   %-16@ used %5.1f%%  left %5.1f%%  %@", w.label as NSString, w.usedPercent, w.leftPercent, resetText(w.resetsAt) as NSString))
            }
            if let e = s?.error { print("   ! \(e)") }
        }
        if let dir = outDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            savePNG(PopoverView(store: store, forImage: true).background(Color(nsColor: .windowBackgroundColor)), "popover-light", dir)
            savePNG(PopoverView(store: store, forImage: true).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark), "popover-dark", dir)
            snapshotPopover(store: store, dark: true, to: "\(dir)/real-popover-dark.png")
            snapshotPopover(store: store, dark: false, to: "\(dir)/real-popover-light.png")
            for dark in [true, false] {
                savePNG(VStack(alignment: .leading, spacing: 8) { ForEach(0..<5) { LabelView(states: store.states, showLeft: true, dark: dark, style: $0) } }
                    .padding(12).background(dark ? Color(red: 0.2, green: 0.3, blue: 0.5) : Color(white: 0.93)), "styles-\(dark ? "dark" : "light")", dir)
            }
            savePNG(LabelView(states: store.states, showLeft: true, dark: false).background(Color(white: 0.93)), "label-light", dir)
            savePNG(LabelView(states: store.states, showLeft: true, dark: true).background(Color(white: 0.15)), "label-dark", dir)
        }
        exit(0)
    }
    RunLoop.main.run()
} else {
    let app = NSApplication.shared
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
