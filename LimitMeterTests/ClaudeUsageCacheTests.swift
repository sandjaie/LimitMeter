@testable import LimitMeterCore
import XCTest

final class ClaudeUsageCacheTests: XCTestCase {
    func testParsesUsedPercentToRemaining() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = Data("""
        {
          "five_hour_pct": 32,
          "five_hour_reset": 1700003600,
          "seven_day_pct": 10,
          "seven_day_reset": 1700864000,
          "updated_at": 1700000000
        }
        """.utf8)

        let snapshot = try XCTUnwrap(ClaudeUsageCache.parse(data: json, now: now, maxAge: 3600))
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent ?? -1, 68, accuracy: 0.01)
        XCTAssertEqual(snapshot.sevenDay?.remainingPercent ?? -1, 90, accuracy: 0.01)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt.timeIntervalSince1970, 1_700_003_600)
    }

    func testRejectsStaleCache() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = Data("""
        {
          "five_hour_pct": 10,
          "five_hour_reset": 1700003600,
          "seven_day_pct": null,
          "seven_day_reset": null,
          "updated_at": 1699900000
        }
        """.utf8)

        XCTAssertNil(ClaudeUsageCache.parse(data: json, now: now, maxAge: 6 * 3600))
    }

    func testAllowsPartialWindows() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = Data("""
        {
          "five_hour_pct": null,
          "five_hour_reset": null,
          "seven_day_pct": 5,
          "seven_day_reset": 1700864000,
          "updated_at": 1700000000
        }
        """.utf8)

        let snapshot = try XCTUnwrap(ClaudeUsageCache.parse(data: json, now: now, maxAge: 3600))
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.sevenDay?.remainingPercent ?? -1, 95, accuracy: 0.01)
    }

    func testRejectsEmptyWindows() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = Data("""
        {
          "five_hour_pct": null,
          "seven_day_pct": null,
          "updated_at": 1700000000
        }
        """.utf8)

        XCTAssertNil(ClaudeUsageCache.parse(data: json, now: now, maxAge: 3600))
    }
}
