import Foundation

public enum ProviderID: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude
    case codex

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

public struct LimitWindow: Equatable, Sendable {
    public var remainingPercent: Double
    public var resetsAt: Date

    public init(remainingPercent: Double, resetsAt: Date) {
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public enum FetchStatus: Equatable, Sendable {
    /// Live data from the provider API.
    case ok
    /// No saved credentials (or session expired).
    case needsAuth
    case error(String)
}

/// Where the current window numbers came from.
public enum UsageDataSource: Equatable, Sendable {
    /// Provider HTTP usage endpoint.
    case live
    /// Claude Code statusline cache (`~/.claude/usage-cache.json`).
    case localCache
}

public struct ProviderUsage: Equatable, Sendable {
    public var provider: ProviderID
    public var planLabel: String?
    public var fiveHour: LimitWindow?
    public var sevenDay: LimitWindow?
    public var fetchedAt: Date
    public var status: FetchStatus
    /// True when Keychain / Codex auth file credentials are present.
    public var isSignedIn: Bool
    public var dataSource: UsageDataSource

    public init(
        provider: ProviderID,
        planLabel: String? = nil,
        fiveHour: LimitWindow? = nil,
        sevenDay: LimitWindow? = nil,
        fetchedAt: Date = Date(),
        status: FetchStatus,
        isSignedIn: Bool = false,
        dataSource: UsageDataSource = .live
    ) {
        self.provider = provider
        self.planLabel = planLabel
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.fetchedAt = fetchedAt
        self.status = status
        self.isSignedIn = isSignedIn
        self.dataSource = dataSource
    }

    public static func signedOut(_ provider: ProviderID) -> ProviderUsage {
        ProviderUsage(provider: provider, status: .needsAuth, isSignedIn: false)
    }
}
