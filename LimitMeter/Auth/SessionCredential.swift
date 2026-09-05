import Foundation

public struct SessionCredential: Codable, Equatable, Sendable {
    /// Cookie header value for Claude, or bearer access token for Codex.
    public var token: String
    /// Claude org UUID, or ChatGPT account id for Codex.
    public var accountID: String?
    public var updatedAt: Date

    public init(token: String, accountID: String? = nil, updatedAt: Date = Date()) {
        self.token = token
        self.accountID = accountID
        self.updatedAt = updatedAt
    }
}
