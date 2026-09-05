import Foundation

public struct CodexUsageClient: UsageClient {
    public var provider: ProviderID {
        .codex
    }

    var http: any HTTPPerforming
    var baseURL: URL

    public init(http: any HTTPPerforming = URLSessionHTTPClient(), baseURL: URL = URL(string: "https://chatgpt.com")!) {
        self.http = http
        self.baseURL = baseURL
    }

    public func fetch(credential: SessionCredential) async -> ProviderUsage {
        let now = Date()
        guard let url = URL(string: "/backend-api/wham/usage", relativeTo: baseURL)?.absoluteURL else {
            return failed(now: now, message: FetchErrorCopy.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        if let accountID = credential.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let response = try await http.data(for: request)
            if response.statusCode == 401 || response.statusCode == 403 {
                return ProviderUsage(
                    provider: .codex,
                    planLabel: nil,
                    fiveHour: nil,
                    sevenDay: nil,
                    fetchedAt: now,
                    status: .needsAuth
                )
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                return failed(now: now, message: FetchErrorCopy.message(forHTTPStatus: response.statusCode))
            }
            return try Self.parse(data: response.data, fetchedAt: now)
        } catch {
            return failed(now: now, message: FetchErrorCopy.message(for: error))
        }
    }

    public static func parse(data: Data, fetchedAt: Date = Date()) throws -> ProviderUsage {
        let decoded = try JSONDecoder().decode(CodexUsagePayload.self, from: data)
        let primary = decoded.rate_limit?.primary_window
        let secondary = decoded.rate_limit?.secondary_window
        return ProviderUsage(
            provider: .codex,
            planLabel: decoded.plan_type?.capitalized,
            fiveHour: primary.map(Self.window(from:)),
            sevenDay: secondary.map(Self.window(from:)),
            fetchedAt: fetchedAt,
            status: .ok
        )
    }

    /// Loads Codex CLI credentials from `~/.codex/auth.json` when present.
    public static func credentialFromCodexAuthFile(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SessionCredential? {
        let url = homeURL.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let tokens = json["tokens"] as? [String: Any]
        let access = (tokens?["access_token"] as? String) ?? (json["access_token"] as? String)
        guard let access, !access.isEmpty else { return nil }

        let accountID = (tokens?["account_id"] as? String)
            ?? (json["account_id"] as? String)
            ?? (json["chatgpt_account_id"] as? String)

        return SessionCredential(token: access, accountID: accountID)
    }

    private static func window(from raw: CodexWindowPayload) -> LimitWindow {
        let remaining = UsageFormatting.remainingPercent(used: raw.used_percent)
        let resetsAt = if let resetAt = raw.reset_at {
            Date(timeIntervalSince1970: TimeInterval(resetAt))
        } else if let after = raw.reset_after_seconds {
            Date().addingTimeInterval(TimeInterval(after))
        } else {
            Date()
        }
        return LimitWindow(remainingPercent: remaining, resetsAt: resetsAt)
    }

    private func failed(now: Date, message: String) -> ProviderUsage {
        ProviderUsage(
            provider: .codex,
            planLabel: nil,
            fiveHour: nil,
            sevenDay: nil,
            fetchedAt: now,
            status: .error(message)
        )
    }
}

private struct CodexUsagePayload: Decodable {
    var plan_type: String?
    var rate_limit: CodexRateLimitPayload?
}

private struct CodexRateLimitPayload: Decodable {
    var primary_window: CodexWindowPayload?
    var secondary_window: CodexWindowPayload?
}

private struct CodexWindowPayload: Decodable {
    var used_percent: Double
    var reset_at: Int?
    var reset_after_seconds: Int?
}
