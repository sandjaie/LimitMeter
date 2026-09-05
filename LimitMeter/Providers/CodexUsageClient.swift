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
        let classified = classifyWindows(
            primary: decoded.rate_limit?.primary_window,
            secondary: decoded.rate_limit?.secondary_window,
            now: fetchedAt
        )
        return ProviderUsage(
            provider: .codex,
            planLabel: decoded.plan_type?.capitalized,
            fiveHour: classified.fiveHour.map(Self.window(from:)),
            sevenDay: classified.sevenDay.map(Self.window(from:)),
            fetchedAt: fetchedAt,
            status: .ok
        )
    }

    /// Map Codex `primary`/`secondary` by window length — not by field name.
    /// Some plans (e.g. Prolite) only expose a weekly limit in `primary_window`.
    static func classifyWindows(
        primary: CodexWindowPayload?,
        secondary: CodexWindowPayload?,
        now: Date = Date()
    ) -> (fiveHour: CodexWindowPayload?, sevenDay: CodexWindowPayload?) {
        var fiveHour: CodexWindowPayload?
        var sevenDay: CodexWindowPayload?

        for raw in [primary, secondary].compactMap({ $0 }) {
            switch kind(of: raw, now: now) {
            case .fiveHour:
                if fiveHour == nil {
                    fiveHour = raw
                }
            case .sevenDay:
                if sevenDay == nil {
                    sevenDay = raw
                }
            }
        }
        return (fiveHour, sevenDay)
    }

    private static func kind(of raw: CodexWindowPayload, now: Date) -> CodexWindowKind {
        if let seconds = raw.limit_window_seconds {
            return seconds <= 12 * 3600 ? .fiveHour : .sevenDay
        }
        if let after = raw.reset_after_seconds {
            return after <= 12 * 3600 ? .fiveHour : .sevenDay
        }
        if let resetAt = raw.reset_at {
            let remaining = resetAt - Int(now.timeIntervalSince1970)
            return remaining <= 12 * 3600 ? .fiveHour : .sevenDay
        }
        // Unknown shape: treat as 5hr only when we have no better signal (legacy).
        return .fiveHour
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

struct CodexWindowPayload: Decodable, Equatable {
    var used_percent: Double
    var limit_window_seconds: Int?
    var reset_at: Int?
    var reset_after_seconds: Int?
}

private enum CodexWindowKind {
    case fiveHour
    case sevenDay
}
