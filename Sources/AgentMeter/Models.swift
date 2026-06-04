import Foundation

/// A single usage window (e.g. 5-hour or 7-day) normalized across providers.
struct UsageWindow: Identifiable {
    let id = UUID()
    let label: String        // "5h", "7d", "7d Opus", ...
    let percent: Double       // 0...100
    let resetAt: Date?

    var resetDescription: String {
        guard let resetAt else { return "—" }
        let now = Date()
        if resetAt <= now { return "resetting" }
        let secs = Int(resetAt.timeIntervalSince(now))
        let d = secs / 86_400
        let h = (secs % 86_400) / 3_600
        let m = (secs % 3_600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

/// Snapshot of one provider's usage at a point in time.
struct ProviderUsage {
    let provider: Provider
    var windows: [UsageWindow] = []
    var planLabel: String? = nil      // "team", "max", subscription type, etc.
    var creditsLabel: String? = nil   // optional extra-usage / credit note
    var error: String? = nil          // human-readable error if the fetch failed
    var updatedAt: Date? = nil

    /// The highest utilization across windows — drives the menu-bar color/summary.
    var peakPercent: Double { windows.map(\.percent).max() ?? 0 }
}

enum Provider: String, CaseIterable {
    case claude = "Claude Code"
    case codex = "Codex"

    var short: String { self == .claude ? "CC" : "CX" }
    var symbol: String { self == .claude ? "✳" : "⬢" }
}

enum Severity {
    case ok, warn, critical, unknown

    static func from(_ percent: Double) -> Severity {
        switch percent {
        case ..<50: return .ok
        case ..<80: return .warn
        default: return .critical
        }
    }
}
