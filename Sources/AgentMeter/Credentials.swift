import Foundation

/// Reads OAuth credentials from the local Claude Code keychain item and the
/// Codex auth.json file. The app only ever *reads* these; it never mutates the
/// user's credentials, so it can never corrupt an active CLI session.
enum Credentials {

    // MARK: - Claude Code (macOS keychain: "Claude Code-credentials")

    struct ClaudeCreds {
        let accessToken: String
        let expiresAt: Date?
        let subscriptionType: String?
    }

    static func claude() -> ClaudeCreds? {
        guard let raw = keychainGenericPassword(service: "Claude Code-credentials"),
              let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }

        var expires: Date? = nil
        if let ms = oauth["expiresAt"] as? Double {
            expires = Date(timeIntervalSince1970: ms / 1000.0)
        }
        return ClaudeCreds(
            accessToken: token,
            expiresAt: expires,
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    /// Run `security find-generic-password -s <service> -w` and capture stdout.
    private static func keychainGenericPassword(service: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", service, "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let out = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            return String(data: out, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - Codex (~/.codex/auth.json)

    struct CodexCreds {
        let accessToken: String
        let accountId: String?
    }

    static func codex() -> CodexCreds? {
        let path = ("~/.codex/auth.json" as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String
        else { return nil }
        return CodexCreds(accessToken: token, accountId: tokens["account_id"] as? String)
    }
}
