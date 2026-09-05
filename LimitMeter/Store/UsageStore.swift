import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
    private static let menuBarProviderKey = "menuBarProvider"
    private static let rateLimitPollSeconds: TimeInterval = 300

    public var claude: ProviderUsage
    public var codex: ProviderUsage
    public var menuBarProvider: ProviderID {
        didSet {
            UserDefaults.standard.set(menuBarProvider.rawValue, forKey: Self.menuBarProviderKey)
        }
    }

    public var isRefreshing = false
    public var showingSignInFor: ProviderID?

    private let credentials: CredentialStore
    private let claudeClient: any UsageClient
    private let codexClient: any UsageClient
    private var pollTask: Task<Void, Never>?
    private var basePollInterval: TimeInterval = 240

    public var menuBarUsage: ProviderUsage {
        switch menuBarProvider {
        case .claude: claude
        case .codex: codex
        }
    }

    public init(
        claude: ProviderUsage = .signedOut(.claude),
        codex: ProviderUsage = .signedOut(.codex),
        menuBarProvider: ProviderID? = nil,
        credentials: CredentialStore = CredentialStore(),
        claudeClient: any UsageClient = ClaudeUsageClient(),
        codexClient: any UsageClient = CodexUsageClient()
    ) {
        self.claude = claude
        self.codex = codex
        self.credentials = credentials
        self.claudeClient = claudeClient
        self.codexClient = codexClient
        if let menuBarProvider {
            self.menuBarProvider = menuBarProvider
        } else if let raw = UserDefaults.standard.string(forKey: Self.menuBarProviderKey),
                  let saved = ProviderID(rawValue: raw) {
            self.menuBarProvider = saved
        } else {
            self.menuBarProvider = .claude
        }
    }

    public func startPolling(intervalSeconds: TimeInterval = 240) {
        basePollInterval = intervalSeconds
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.refreshAll()
            while let self, !Task.isCancelled {
                let delay = nextPollDelay()
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                await refreshAll()
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let claudeResult = refresh(provider: .claude)
        async let codexResult = refresh(provider: .codex)
        let (nextClaude, nextCodex) = await (claudeResult, codexResult)
        claude = nextClaude
        codex = nextCodex
    }

    public func saveCredential(_ credential: SessionCredential, for provider: ProviderID) throws {
        try credentials.save(credential, for: provider)
        UserDefaults.standard.set(false, forKey: Self.optOutKey(for: provider))
        showingSignInFor = nil
    }

    public func signOut(_ provider: ProviderID) throws {
        try credentials.delete(provider)
        UserDefaults.standard.set(true, forKey: Self.optOutKey(for: provider))
        switch provider {
        case .claude: claude = .signedOut(.claude)
        case .codex: codex = .signedOut(.codex)
        }
    }

    /// Back off while either provider is rate-limited so we don't keep hammering the API.
    /// Also slow down while Claude is served from the statusline cache (usually after 429).
    func nextPollDelay() -> TimeInterval {
        if isRateLimited(claude) || isRateLimited(codex) || claude.dataSource == .localCache {
            return max(basePollInterval, Self.rateLimitPollSeconds)
        }
        return basePollInterval
    }

    private func refresh(provider: ProviderID) async -> ProviderUsage {
        let previous = snapshot(for: provider)
        let credential: SessionCredential?
        do {
            credential = try resolveCredential(for: provider)
        } catch {
            return Self.preservingLastKnown(
                previous: previous,
                next: ProviderUsage(
                    provider: provider,
                    fetchedAt: Date(),
                    status: .error(FetchErrorCopy.message(for: error)),
                    isSignedIn: false
                )
            )
        }

        guard let credential else {
            return .signedOut(provider)
        }

        var usage: ProviderUsage = switch provider {
        case .claude:
            await claudeClient.fetch(credential: credential)
        case .codex:
            await codexClient.fetch(credential: credential)
        }
        usage.isSignedIn = true
        if case .needsAuth = usage.status {
            usage.isSignedIn = false
        }
        return Self.preservingLastKnown(previous: previous, next: usage)
    }

    private func snapshot(for provider: ProviderID) -> ProviderUsage {
        switch provider {
        case .claude: claude
        case .codex: codex
        }
    }

    private func isRateLimited(_ usage: ProviderUsage) -> Bool {
        if case let .error(message) = usage.status {
            return FetchErrorCopy.isRateLimitedMessage(message)
        }
        return false
    }

    /// Keep last known % / plan when a refresh fails, needs re-auth, or returns a
    /// partial Claude Code cache snapshot (statusline often omits one window).
    static func preservingLastKnown(previous: ProviderUsage, next: ProviderUsage) -> ProviderUsage {
        switch next.status {
        case .ok where next.dataSource == .localCache:
            var merged = next
            if merged.fiveHour == nil {
                merged.fiveHour = previous.fiveHour
            }
            if merged.sevenDay == nil {
                merged.sevenDay = previous.sevenDay
            }
            if merged.planLabel == nil {
                merged.planLabel = previous.planLabel
            }
            return merged
        case .ok:
            return next
        case .needsAuth, .error:
            var merged = next
            if merged.fiveHour == nil {
                merged.fiveHour = previous.fiveHour
            }
            if merged.sevenDay == nil {
                merged.sevenDay = previous.sevenDay
            }
            if merged.planLabel == nil {
                merged.planLabel = previous.planLabel
            }
            if merged.dataSource == .live, previous.dataSource == .localCache,
               merged.fiveHour != nil || merged.sevenDay != nil {
                merged.dataSource = .localCache
            }
            return merged
        }
    }

    private func resolveCredential(for provider: ProviderID) throws -> SessionCredential? {
        if let stored = try credentials.load(provider) {
            return stored
        }
        if UserDefaults.standard.bool(forKey: Self.optOutKey(for: provider)) {
            return nil
        }
        switch provider {
        case .claude:
            if let imported = try ClaudeCodeAuth.loadCredential() {
                try? credentials.save(imported, for: .claude)
                return imported
            }
        case .codex:
            if let imported = CodexUsageClient.credentialFromCodexAuthFile() {
                try? credentials.save(imported, for: .codex)
                return imported
            }
        }
        return nil
    }

    private static func optOutKey(for provider: ProviderID) -> String {
        "optOut.\(provider.rawValue)"
    }
}
