@testable import LimitMeterCore
import XCTest

final class ClaudeUsageParsingTests: XCTestCase {
    func testParsesFiveHourAndSevenDayRemaining() throws {
        let data = try fixture("claude_usage")
        let usage = try ClaudeUsageClient.parse(data: data, fetchedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(usage.provider, .claude)
        XCTAssertEqual(usage.status, .ok)
        XCTAssertEqual(usage.fiveHour?.remainingPercent ?? -1, 62, accuracy: 0.01)
        XCTAssertEqual(usage.sevenDay?.remainingPercent ?? -1, 81, accuracy: 0.01)
        XCTAssertEqual(usage.fiveHour?.resetsAt, ISO8601DateFormatter().date(from: "2026-09-05T20:14:00Z"))
    }

    private func fixture(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: name, withExtension: "json")
        #else
            let url = Bundle(for: ClaudeUsageParsingTests.self).url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures"
            )
                ?? Bundle(for: ClaudeUsageParsingTests.self).url(forResource: name, withExtension: "json")
        #endif
        let resolved = try XCTUnwrap(url)
        return try Data(contentsOf: resolved)
    }
}
