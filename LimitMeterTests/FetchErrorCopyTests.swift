@testable import LimitMeterCore
import XCTest

final class FetchErrorCopyTests: XCTestCase {
    func testHTTP429MapsToRateLimitedCopy() {
        XCTAssertEqual(FetchErrorCopy.message(forHTTPStatus: 429), FetchErrorCopy.rateLimited)
        XCTAssertTrue(FetchErrorCopy.isRateLimitedMessage(FetchErrorCopy.rateLimited))
    }

    func testHTTP5xxMapsToUnavailable() {
        XCTAssertEqual(FetchErrorCopy.message(forHTTPStatus: 503), FetchErrorCopy.providerUnavailable)
    }

    func testOtherHTTPUsesFriendlyFallback() {
        XCTAssertEqual(FetchErrorCopy.message(forHTTPStatus: 418), "Couldn’t load usage (error 418).")
    }

    func testURLErrorOffline() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(FetchErrorCopy.message(for: error), FetchErrorCopy.offline)
    }

    func testURLErrorTimeout() {
        let error = URLError(.timedOut)
        XCTAssertEqual(FetchErrorCopy.message(for: error), FetchErrorCopy.timedOut)
    }

    func testDecodingError() {
        struct Dummy: Decodable { var x: Int }
        do {
            _ = try JSONDecoder().decode(Dummy.self, from: Data("{}".utf8))
            XCTFail("expected decode failure")
        } catch {
            XCTAssertEqual(FetchErrorCopy.message(for: error), FetchErrorCopy.invalidResponse)
        }
    }
}

@MainActor
final class UsageStoreErrorMergeTests: XCTestCase {
    func testPreservingLastKnownKeepsWindowsOnError() {
        let previous = ProviderUsage(
            provider: .claude,
            planLabel: "Pro",
            fiveHour: LimitWindow(remainingPercent: 68, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: LimitWindow(remainingPercent: 90, resetsAt: Date().addingTimeInterval(86400)),
            status: .ok,
            isSignedIn: true
        )
        let next = ProviderUsage(
            provider: .claude,
            status: .error(FetchErrorCopy.rateLimited),
            isSignedIn: true
        )
        let merged = UsageStore.preservingLastKnown(previous: previous, next: next)
        XCTAssertEqual(merged.status, .error(FetchErrorCopy.rateLimited))
        XCTAssertEqual(merged.fiveHour?.remainingPercent, 68)
        XCTAssertEqual(merged.sevenDay?.remainingPercent, 90)
        XCTAssertEqual(merged.planLabel, "Pro")
    }

    func testPreservingLastKnownMergesPartialLocalCache() {
        let previous = ProviderUsage(
            provider: .claude,
            planLabel: "Pro",
            fiveHour: LimitWindow(remainingPercent: 68, resetsAt: Date().addingTimeInterval(3600)),
            sevenDay: LimitWindow(remainingPercent: 90, resetsAt: Date().addingTimeInterval(86400)),
            status: .ok,
            isSignedIn: true,
            dataSource: .live
        )
        let next = ProviderUsage(
            provider: .claude,
            fiveHour: nil,
            sevenDay: LimitWindow(remainingPercent: 95, resetsAt: Date().addingTimeInterval(21 * 3600)),
            status: .ok,
            isSignedIn: true,
            dataSource: .localCache
        )
        let merged = UsageStore.preservingLastKnown(previous: previous, next: next)
        XCTAssertEqual(merged.dataSource, .localCache)
        XCTAssertEqual(merged.fiveHour?.remainingPercent, 68)
        XCTAssertEqual(merged.sevenDay?.remainingPercent, 95)
        XCTAssertEqual(merged.planLabel, "Pro")
    }

    func testPreservingLastKnownDoesNotOverrideOk() {
        let previous = ProviderUsage(
            provider: .claude,
            fiveHour: LimitWindow(remainingPercent: 10, resetsAt: Date()),
            status: .ok,
            isSignedIn: true
        )
        let next = ProviderUsage(
            provider: .claude,
            fiveHour: LimitWindow(remainingPercent: 50, resetsAt: Date()),
            status: .ok,
            isSignedIn: true
        )
        let merged = UsageStore.preservingLastKnown(previous: previous, next: next)
        XCTAssertEqual(merged.fiveHour?.remainingPercent, 50)
    }
}
