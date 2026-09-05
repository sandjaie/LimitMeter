import Foundation

public enum UsageFormatting {
    /// Converts server "used" / utilization (0...100 or 0...1) into remaining percent 0...100.
    public static func remainingPercent(used: Double) -> Double {
        let usedPercent: Double = if used <= 1.0 {
            used * 100.0
        } else {
            used
        }
        return max(0, min(100, 100.0 - usedPercent))
    }

    public static func relativeCountdown(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(minutes, 0))m"
    }

    public static func percentText(_ remaining: Double) -> String {
        "\(Int(remaining.rounded()))%"
    }

    /// Menu bar fragment for one window: `5hr: 62% · 2h 14m` (never includes "resets").
    public static func windowFragment(label: String, window: LimitWindow?, now: Date = Date()) -> String {
        guard let window else {
            return "\(label): —"
        }
        let pct = percentText(window.remainingPercent)
        let when = relativeCountdown(until: window.resetsAt, now: now)
        return "\(label): \(pct) · \(when)"
    }

    public static func menuBarText(usage: ProviderUsage, now: Date = Date()) -> String {
        let five = windowFragment(label: "5hr", window: usage.fiveHour, now: now)
        let seven = windowFragment(label: "7D", window: usage.sevenDay, now: now)
        return "\(five) | \(seven)"
    }
}
