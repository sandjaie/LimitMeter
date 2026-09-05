@testable import LimitMeterCore
import XCTest

final class LimitColorTests: XCTestCase {
    func testSeverityThresholds() {
        XCTAssertEqual(LimitColor.severity(for: 40), .ok)
        XCTAssertEqual(LimitColor.severity(for: 39.9), .warn)
        XCTAssertEqual(LimitColor.severity(for: 15), .warn)
        XCTAssertEqual(LimitColor.severity(for: 14.9), .critical)
        XCTAssertEqual(LimitColor.severity(for: nil), .unknown)
    }
}
