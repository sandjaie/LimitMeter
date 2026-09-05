import Foundation

/// Loads the Claude Code OAuth session already on this Mac (subscription login).
public enum ClaudeCodeAuth {
    public static var isAvailable: Bool {
        (try? loadCredential()) != nil
    }

    /// Reads Claude Code credentials from Keychain or `~/.claude/.credentials.json`.
    public static func loadCredential(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> SessionCredential? {
        if let fromKeychain = try loadFromKeychain() {
            return fromKeychain
        }
        return try loadFromCredentialsFile(homeURL: homeURL)
    }

    private static func loadFromKeychain() throws -> SessionCredential? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", "Claude Code-credentials",
            "-w",
        ]
        let pipe = Pipe()
        let err = Pipe()
        process.standardOutput = pipe
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return try parseCredentialJSON(raw.data(using: .utf8) ?? data)
    }

    private static func loadFromCredentialsFile(homeURL: URL) throws -> SessionCredential? {
        let candidates = [
            homeURL.appendingPathComponent(".claude/.credentials.json"),
            homeURL.appendingPathComponent(".claude/credentials.json"),
        ]
        for url in candidates {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url) else { continue }
            if let credential = try? parseCredentialJSON(data) {
                return credential
            }
        }
        return nil
    }

    private static func parseCredentialJSON(_ data: Data) throws -> SessionCredential? {
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let oauth = (obj?["claudeAiOauth"] as? [String: Any]) ?? obj
        guard let oauth,
              let access = oauth["accessToken"] as? String,
              !access.isEmpty else {
            return nil
        }
        let plan = oauth["subscriptionType"] as? String
        return SessionCredential(
            token: access,
            accountID: plan.map { "oauth:\($0)" } ?? "oauth"
        )
    }
}
