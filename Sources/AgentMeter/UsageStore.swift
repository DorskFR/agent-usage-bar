import Foundation
import Combine
import AppKit

/// Owns the polling loop and publishes the latest usage for both providers.
@MainActor
final class UsageStore: ObservableObject {
    @Published var claude = ProviderUsage(provider: .claude)
    @Published var codex = ProviderUsage(provider: .codex)
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?

    /// Poll interval in seconds. Anthropic's endpoint is safe at ~180s; keep a
    /// comfortable default that respects both providers' rate limits.
    @Published var interval: TimeInterval {
        didSet {
            UserDefaults.standard.set(interval, forKey: "pollInterval")
            scheduleTimer()
        }
    }

    static let intervalOptions: [(String, TimeInterval)] = [
        ("1 min", 60), ("3 min", 180), ("5 min", 300), ("10 min", 600)
    ]

    private var timer: Timer?
    var onUpdate: (() -> Void)?

    init() {
        let saved = UserDefaults.standard.double(forKey: "pollInterval")
        interval = saved >= 60 ? saved : 180
    }

    func start() {
        scheduleTimer()
        Task { await refresh() }
        // Refresh promptly after the machine wakes from sleep.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        async let c = UsageFetcher.fetchClaude()
        async let x = UsageFetcher.fetchCodex()
        claude = await c
        codex = await x
        lastUpdated = Date()
        isRefreshing = false
        onUpdate?()
    }
}
