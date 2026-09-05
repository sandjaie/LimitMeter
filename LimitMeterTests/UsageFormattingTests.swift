@testable import LimitMeterCore
import XCTest

final class UsageFormattingTests: XCTestCase {
    func testRemainingPercentFromUtilizationFraction() {
        XCTAssertEqual(UsageFormatting.remainingPercent(used: 0.38), 62, accuracy: 0.01)
    }

    func testRemainingPercentFromUsedPercent() {
        XCTAssertEqual(UsageFormatting.remainingPercent(used: 38), 62, accuracy: 0.01)
    }

    func testMenuBarTextOmitsResetsWord() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let usage = ProviderUsage(
            provider: .claude,
            planLabel: nil,
            fiveHour: LimitWindow(remainingPercent: 62, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
            sevenDay: LimitWindow(remainingPercent: 81, resetsAt: now.addingTimeInterval(4 * 86400 + 3 * 3600)),
            fetchedAt: now,
            status: .ok
        )
        let text = UsageFormatting.menuBarText(usage: usage, now: now)
        XCTAssertFalse(text.lowercased().contains("resets"))
        XCTAssertEqual(text, "5hr: 62% · 2h 14m | 7D: 81% · 4d 3h")
    }

    func testRelativeCountdownMinutesOnly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = UsageFormatting.relativeCountdown(until: now.addingTimeInterval(12 * 60), now: now)
        XCTAssertEqual(text, "12m")
    }
}
