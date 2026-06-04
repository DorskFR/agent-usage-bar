import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = UsageStore()
    private var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "··"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(store: store, onQuit: { NSApp.terminate(nil) })
        )

        store.onUpdate = { [weak self] in self?.updateTitle() }
        store.start()
        updateTitle()
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }

        func segment(_ u: ProviderUsage) -> (text: String, sev: Severity) {
            if u.error != nil { return ("\(u.provider.short) —", .unknown) }
            if u.windows.isEmpty { return ("\(u.provider.short) ··", .unknown) }
            let p = u.peakPercent
            return ("\(u.provider.short) \(Int(p.rounded()))%", Severity.from(p))
        }

        let cc = segment(store.claude)
        let cx = segment(store.codex)
        let worst = [cc.sev, cx.sev].contains(.critical) ? Severity.critical
            : [cc.sev, cx.sev].contains(.warn) ? .warn : .ok

        let dot: String
        switch worst {
        case .ok: dot = "🟢"
        case .warn: dot = "🟡"
        case .critical: dot = "🔴"
        case .unknown: dot = "⚪️"
        }

        button.title = "\(dot) \(cc.text) · \(cx.text)"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Task { await store.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// `AgentMeter --once` fetches both providers, prints a summary, and exits.
// Useful for testing/scripting without the menu-bar UI.
if CommandLine.arguments.contains("--once") {
    let sema = DispatchSemaphore(value: 0)
    Task {
        for u in [await UsageFetcher.fetchClaude(), await UsageFetcher.fetchCodex()] {
            print("\(u.provider.symbol) \(u.provider.rawValue)" +
                  (u.planLabel.map { " [\($0)]" } ?? ""))
            if let e = u.error { print("   ⚠️  \(e.replacingOccurrences(of: "\n", with: " "))") }
            for w in u.windows {
                print(String(format: "   %-10@ %5.1f%%  resets in %@",
                             w.label as NSString, w.percent, w.resetDescription))
            }
            if let c = u.creditsLabel { print("   \(c)") }
        }
        sema.signal()
    }
    sema.wait()
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
