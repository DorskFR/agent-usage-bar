import Foundation

/// Fetches usage from the same OAuth endpoints the Claude Code and Codex CLIs use.
enum UsageFetcher {

    /// Claude Code CLI version string, used for the required User-Agent header.
    static let claudeCodeVersion = "2.1.162"

    // MARK: - Claude

    static func fetchClaude() async -> ProviderUsage {
        var result = ProviderUsage(provider: .claude)

        guard let creds = Credentials.claude() else {
            result.error = "No Claude Code login found.\nRun `claude` to sign in."
            return result
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        // The User-Agent is required — without it the endpoint hits an aggressive 429 bucket.
        req.setValue("claude-code/\(claudeCodeVersion)", forHTTPHeaderField: "User-Agent")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.timeoutInterval = 20

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 {
                result.error = "Claude token expired.\nRun `claude` to refresh."
                return result
            }
            if code == 429 {
                result.error = "Rate limited by Anthropic.\nWill retry shortly."
                return result
            }
            guard code == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                result.error = "Unexpected response (HTTP \(code))."
                return result
            }

            func window(_ key: String, _ label: String) -> UsageWindow? {
                guard let obj = json[key] as? [String: Any],
                      let util = obj["utilization"] as? Double else { return nil }
                return UsageWindow(label: label, percent: util,
                                   resetAt: parseISO(obj["resets_at"] as? String))
            }

            var windows: [UsageWindow] = []
            if let w = window("five_hour", "5h") { windows.append(w) }
            if let w = window("seven_day", "7d") { windows.append(w) }
            if let w = window("seven_day_opus", "7d Opus") { windows.append(w) }
            if let w = window("seven_day_sonnet", "7d Sonnet") { windows.append(w) }
            result.windows = windows

            result.planLabel = creds.subscriptionType

            if let extra = json["extra_usage"] as? [String: Any],
               (extra["is_enabled"] as? Bool) == true {
                let used = extra["used_credits"] as? Double ?? 0
                let limit = extra["monthly_limit"] as? Double ?? 0
                let cur = extra["currency"] as? String ?? "USD"
                if limit > 0 || used > 0 {
                    result.creditsLabel = String(format: "Extra: %.2f / %.0f %@", used, limit, cur)
                }
            }

            result.updatedAt = Date()
        } catch {
            result.error = "Network error:\n\(error.localizedDescription)"
        }
        return result
    }

    // MARK: - Codex

    static func fetchCodex() async -> ProviderUsage {
        var result = ProviderUsage(provider: .codex)

        guard let creds = Credentials.codex() else {
            result.error = "No Codex login found.\nRun `codex` to sign in."
            return result
        }

        var req = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        if let acc = creds.accountId {
            req.setValue(acc, forHTTPHeaderField: "chatgpt-account-id")
        }
        req.setValue("codex_cli_rs", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 || code == 403 {
                result.error = "Codex token expired.\nRun `codex` to refresh."
                return result
            }
            guard code == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                result.error = "Unexpected response (HTTP \(code))."
                return result
            }

            result.planLabel = json["plan_type"] as? String

            if let rl = json["rate_limit"] as? [String: Any] {
                func window(_ key: String, _ label: String) -> UsageWindow? {
                    guard let obj = rl[key] as? [String: Any] else { return nil }
                    let pct = (obj["used_percent"] as? Double)
                        ?? Double(obj["used_percent"] as? Int ?? 0)
                    let reset = (obj["reset_at"] as? Double)
                        ?? Double(obj["reset_at"] as? Int ?? 0)
                    return UsageWindow(label: label, percent: pct,
                                       resetAt: reset > 0 ? Date(timeIntervalSince1970: reset) : nil)
                }
                var windows: [UsageWindow] = []
                if let w = window("primary_window", "5h") { windows.append(w) }
                if let w = window("secondary_window", "7d") { windows.append(w) }
                result.windows = windows
            }

            if let credits = json["credits"] as? [String: Any],
               (credits["has_credits"] as? Bool) == true,
               let bal = credits["balance"] as? Double {
                result.creditsLabel = String(format: "Credits: %.2f", bal)
            }

            result.updatedAt = Date()
        } catch {
            result.error = "Network error:\n\(error.localizedDescription)"
        }
        return result
    }

    // MARK: - Helpers

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFrac = ISO8601DateFormatter()

    static func parseISO(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return isoFormatter.date(from: s) ?? isoFormatterNoFrac.date(from: s)
    }
}
