import Foundation

public struct ClaudeUsageClient: UsageClient {
    public var provider: ProviderID {
        .claude
    }

    var http: any HTTPPerforming
    var claudeWebBaseURL: URL
    var oauthUsageURL: URL

    public init(
        http: any HTTPPerforming = URLSessionHTTPClient(),
        claudeWebBaseURL: URL = URL(string: "https://claude.ai")!,
        oauthUsageURL: URL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    ) {
        self.http = http
        self.claudeWebBaseURL = claudeWebBaseURL
        self.oauthUsageURL = oauthUsageURL
    }

    public func fetch(credential: SessionCredential) async -> ProviderUsage {
        if isOAuthCredential(credential) {
            return await fetchOAuthUsage(credential: credential)
        }
        return await fetchCookieUsage(credential: credential)
    }

    public static func parse(
        data: Data,
        fetchedAt: Date = Date(),
        planLabel: String? = nil
    ) throws -> ProviderUsage {
        let decoded = try JSONDecoder().decode(ClaudeUsagePayload.self, from: data)
        return ProviderUsage(
            provider: .claude,
            planLabel: planLabel,
            fiveHour: decoded.five_hour.flatMap(Self.window(from:)),
            sevenDay: decoded.seven_day.flatMap(Self.window(from:)),
            fetchedAt: fetchedAt,
            status: .ok
        )
    }

    private func fetchOAuthUsage(credential: SessionCredential) async -> ProviderUsage {
        let now = Date()
        var request = URLRequest(url: oauthUsageURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        do {
            let response = try await http.data(for: request)
            if response.statusCode == 401 || response.statusCode == 403 {
                return ProviderUsage(provider: .claude, fetchedAt: now, status: .needsAuth)
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                return failedOrCache(
                    now: now,
                    planLabel: planLabel(from: credential),
                    message: FetchErrorCopy.message(forHTTPStatus: response.statusCode)
                )
            }
            let plan = planLabel(from: credential)
            return try Self.parse(data: response.data, fetchedAt: now, planLabel: plan)
        } catch {
            return failedOrCache(
                now: now,
                planLabel: planLabel(from: credential),
                message: FetchErrorCopy.message(for: error)
            )
        }
    }

    private func fetchCookieUsage(credential: SessionCredential) async -> ProviderUsage {
        let now = Date()
        guard let orgID = credential.accountID, !orgID.isEmpty, !orgID.hasPrefix("oauth") else {
            return ProviderUsage(provider: .claude, fetchedAt: now, status: .needsAuth)
        }

        guard let url = URL(string: "/api/organizations/\(orgID)/usage", relativeTo: claudeWebBaseURL)?.absoluteURL
        else {
            return failed(now: now, message: FetchErrorCopy.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        request.setValue(cookieHeader(from: credential.token), forHTTPHeaderField: "Cookie")

        do {
            let response = try await http.data(for: request)
            if response.statusCode == 401 || response.statusCode == 403 {
                return ProviderUsage(provider: .claude, fetchedAt: now, status: .needsAuth)
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                return failedOrCache(
                    now: now,
                    planLabel: nil,
                    message: FetchErrorCopy.message(forHTTPStatus: response.statusCode)
                )
            }
            return try Self.parse(data: response.data, fetchedAt: now)
        } catch {
            return failedOrCache(now: now, planLabel: nil, message: FetchErrorCopy.message(for: error))
        }
    }

    private static func window(from raw: ClaudeWindowPayload) -> LimitWindow? {
        guard raw.utilization != nil || raw.resets_at != nil else { return nil }
        let used = raw.utilization ?? 0
        let resetsAt: Date = if let reset = raw.resets_at, let date = parseDate(reset) {
            date
        } else {
            // Idle 5hr window often has null resets_at; keep a neutral countdown.
            Date().addingTimeInterval(5 * 3600)
        }
        return LimitWindow(
            remainingPercent: UsageFormatting.remainingPercent(used: used),
            resetsAt: resetsAt
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: value)
    }

    private func isOAuthCredential(_ credential: SessionCredential) -> Bool {
        if let accountID = credential.accountID, accountID.hasPrefix("oauth") {
            return true
        }
        // Claude Code access tokens are long JWTs / opaque strings, not cookies.
        return credential.accountID == nil && !credential.token.lowercased().contains("sessionkey")
    }

    private func planLabel(from credential: SessionCredential) -> String? {
        guard let accountID = credential.accountID else { return nil }
        if accountID.hasPrefix("oauth:") {
            return String(accountID.dropFirst("oauth:".count)).capitalized
        }
        if accountID == "oauth" {
            return "Pro"
        }
        return nil
    }

    private func cookieHeader(from token: String) -> String {
        if token.lowercased().hasPrefix("sessionkey=") || token.contains(";") {
            return token
        }
        return "sessionKey=\(token)"
    }

    private func failedOrCache(now: Date, planLabel: String?, message: String) -> ProviderUsage {
        if let snapshot = ClaudeUsageCache.load(now: now) {
            var usage = ClaudeUsageCache.providerUsage(from: snapshot, planLabel: planLabel, fetchedAt: now)
            usage.isSignedIn = true
            return usage
        }
        return failed(now: now, message: message)
    }

    private func failed(now: Date, message: String) -> ProviderUsage {
        ProviderUsage(provider: .claude, fetchedAt: now, status: .error(message))
    }
}

private struct ClaudeUsagePayload: Decodable {
    var five_hour: ClaudeWindowPayload?
    var seven_day: ClaudeWindowPayload?
}

private struct ClaudeWindowPayload: Decodable {
    var utilization: Double?
    var resets_at: String?
}
