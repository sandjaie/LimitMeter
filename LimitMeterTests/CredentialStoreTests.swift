@testable import LimitMeterCore
import XCTest

final class CredentialStoreTests: XCTestCase {
    private var store: CredentialStore!
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitMeterTests-\(UUID().uuidString)")
        store = CredentialStore(directoryURL: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        store = nil
        directory = nil
        super.tearDown()
    }

    func testSaveLoadDelete() throws {
        let credential = SessionCredential(token: "abc", accountID: "org-1")
        try store.save(credential, for: .claude)
        let loaded = try store.load(.claude)
        XCTAssertEqual(loaded?.token, "abc")
        XCTAssertEqual(loaded?.accountID, "org-1")
        try store.delete(.claude)
        XCTAssertNil(try store.load(.claude))
    }
}
