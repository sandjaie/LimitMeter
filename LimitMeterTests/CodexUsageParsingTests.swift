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
