import Foundation

public enum MockUsage {
    public static func claude(now: Date = Date()) -> ProviderUsage {
        ProviderUsage(
            provider: .claude,
            planLabel: "Max",
            fiveHour: LimitWindow(remainingPercent: 62, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
            sevenDay: LimitWindow(remainingPercent: 81, resetsAt: now.addingTimeInterval(4 * 86400 + 3 * 3600)),
            fetchedAt: now,
            status: .ok,
            isSignedIn: true
        )
    }

    public static func codex(now: Date = Date()) -> ProviderUsage {
        ProviderUsage(
            provider: .codex,
            planLabel: "Plus",
            fiveHour: LimitWindow(remainingPercent: 41, resetsAt: now.addingTimeInterval(3600 + 2 * 60)),
            sevenDay: LimitWindow(remainingPercent: 74, resetsAt: now.addingTimeInterval(5 * 86400 + 11 * 3600)),
            fetchedAt: now,
            status: .ok,
            isSignedIn: true
        )
    }
}
