import Foundation

/// Reads Claude Code statusline-written `~/.claude/usage-cache.json`.
///
/// Same account-level 5hr/7D numbers Claude injects into the statusline as
/// `rate_limits` (used %). Not derived from local JSONL token logs.
public enum ClaudeUsageCache {
    public static let defaultMaxAge: TimeInterval = 6 * 3600

    public struct Snapshot: Equatable, Sendable {
        public var fiveHour: LimitWindow?
        public var sevenDay: LimitWindow?
        public var updatedAt: Date
    }

    public static func load(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date(),
        maxAge: TimeInterval = defaultMaxAge
    ) -> Snapshot? {
        let url = homeURL.appendingPathComponent(".claude/usage-cache.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data: data, now: now, maxAge: maxAge)
    }

    public static func parse(
        data: Data,
        now: Date = Date(),
        maxAge: TimeInterval = defaultMaxAge
    ) -> Snapshot? {
        guard let raw = try? JSONDecoder().decode(CacheFile.self, from: data) else {
            return nil
        }
        let updatedAt = Date(timeIntervalSince1970: TimeInterval(raw.updated_at))
        guard now.timeIntervalSince(updatedAt) <= maxAge, now.timeIntervalSince(updatedAt) >= -60 else {
            return nil
        }

        let five = window(usedPercent: raw.five_hour_pct, reset: raw.five_hour_reset)
        let seven = window(usedPercent: raw.seven_day_pct, reset: raw.seven_day_reset)
        guard five != nil || seven != nil else { return nil }

        return Snapshot(fiveHour: five, sevenDay: seven, updatedAt: updatedAt)
    }

    public static func providerUsage(
        from snapshot: Snapshot,
        planLabel: String? = nil,
        fetchedAt: Date = Date()
    ) -> ProviderUsage {
        ProviderUsage(
            provider: .claude,
            planLabel: planLabel,
            fiveHour: snapshot.fiveHour,
            sevenDay: snapshot.sevenDay,
            fetchedAt: fetchedAt,
            status: .ok,
            isSignedIn: true,
            dataSource: .localCache
        )
    }

    private static func window(usedPercent: Double?, reset: Int?) -> LimitWindow? {
        guard let usedPercent else { return nil }
        let resetsAt = if let reset {
            Date(timeIntervalSince1970: TimeInterval(reset))
        } else {
            Date()
        }
        return LimitWindow(
            remainingPercent: UsageFormatting.remainingPercent(used: usedPercent),
            resetsAt: resetsAt
        )
    }
}

private struct CacheFile: Decodable {
    var five_hour_pct: Double?
    var five_hour_reset: Int?
    var seven_day_pct: Double?
    var seven_day_reset: Int?
    var updated_at: Int
}
