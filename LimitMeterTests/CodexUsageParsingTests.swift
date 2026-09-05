@testable import LimitMeterCore
import XCTest

final class CodexUsageParsingTests: XCTestCase {
    func testParsesPrimaryAndSecondaryWindows() throws {
        let data = try fixture("codex_usage")
        let usage = try CodexUsageClient.parse(data: data, fetchedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(usage.provider, .codex)
        XCTAssertEqual(usage.planLabel, "Plus")
        XCTAssertEqual(usage.fiveHour?.remainingPercent ?? -1, 41, accuracy: 0.01)
        XCTAssertEqual(usage.sevenDay?.remainingPercent ?? -1, 74, accuracy: 0.01)
        XCTAssertEqual(usage.fiveHour?.resetsAt.timeIntervalSince1970, 1_788_615_000)
    }

    func testWeeklyOnlyPrimaryMapsToSevenDay() throws {
        let data = try fixture("codex_usage_weekly_only")
        let usage = try CodexUsageClient.parse(
            data: data,
            fetchedAt: Date(timeIntervalSince1970: 1_788_654_420)
        )
        XCTAssertNil(usage.fiveHour)
        XCTAssertEqual(usage.sevenDay?.remainingPercent ?? -1, 95, accuracy: 0.01)
        XCTAssertEqual(usage.sevenDay?.resetsAt.timeIntervalSince1970, 1_789_133_220)
        XCTAssertEqual(usage.planLabel, "Prolite")
    }

    func testClassifyUsesLimitWindowSecondsNotFieldName() {
        let weekly = CodexWindowPayload(
            used_percent: 5,
            limit_window_seconds: 604_800,
            reset_at: 1_789_133_220,
            reset_after_seconds: 478_800
        )
        let five = CodexWindowPayload(
            used_percent: 40,
            limit_window_seconds: 18000,
            reset_at: 1_788_615_000,
            reset_after_seconds: 3720
        )
        // Swap field order vs usual naming: weekly in primary, 5hr in secondary.
        let classified = CodexUsageClient.classifyWindows(primary: weekly, secondary: five)
        XCTAssertEqual(classified.fiveHour?.used_percent, 40)
        XCTAssertEqual(classified.sevenDay?.used_percent, 5)
    }

    private func fixture(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: name, withExtension: "json")
        #else
            let url = Bundle(for: CodexUsageParsingTests.self).url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures"
            )
                ?? Bundle(for: CodexUsageParsingTests.self).url(forResource: name, withExtension: "json")
        #endif
        let resolved = try XCTUnwrap(url)
        return try Data(contentsOf: resolved)
    }
}
