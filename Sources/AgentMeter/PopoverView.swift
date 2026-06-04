import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ProviderSection(usage: store.claude)
            Divider()
            ProviderSection(usage: store.codex)
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("Agent Usage").font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Picker("", selection: Binding(
                get: { store.interval },
                set: { store.interval = $0 })
            ) {
                ForEach(UsageStore.intervalOptions, id: \.1) { name, val in
                    Text(name).tag(val)
                }
            }
            .labelsHidden()
            .frame(width: 90)
            .help("Refresh interval")

            Spacer()

            if let updated = store.lastUpdated {
                Text("updated \(timeAgo(updated))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }
}

private struct ProviderSection: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(usage.provider.symbol)
                Text(usage.provider.rawValue).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let plan = usage.planLabel {
                    Text(plan.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let err = usage.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if usage.windows.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(usage.windows) { w in
                    WindowRow(window: w)
                }
                if let credits = usage.creditsLabel {
                    Text(credits).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }
}

private struct WindowRow: View {
    let window: UsageWindow

    private var color: Color {
        switch Severity.from(window.percent) {
        case .ok: return .green
        case .warn: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(window.percent.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(color)
                Text("· \(window.resetDescription)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: max(2, geo.size.width * min(1, window.percent / 100)))
                }
            }
            .frame(height: 5)
        }
    }
}
