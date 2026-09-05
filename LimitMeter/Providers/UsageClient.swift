import Foundation

public protocol UsageClient: Sendable {
    var provider: ProviderID { get }
    func fetch(credential: SessionCredential) async -> ProviderUsage
}
