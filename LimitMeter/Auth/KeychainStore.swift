import Foundation

public enum CredentialStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case ioFailed
}

/// Stores provider sessions under Application Support (mode 0600).
/// Avoids macOS Keychain ACL prompts that hit ad-hoc / SwiftPM builds every relaunch.
public struct CredentialStore: Sendable {
    public var directoryURL: URL

    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("LimitMeter", isDirectory: true)
        }
    }

    public func save(_ credential: SessionCredential, for provider: ProviderID) throws {
        try ensureDirectory()
        let data: Data
        do {
            data = try JSONEncoder().encode(credential)
        } catch {
            throw CredentialStoreError.encodingFailed
        }
        let url = fileURL(for: provider)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw CredentialStoreError.ioFailed
        }
    }

    public func load(_ provider: ProviderID) throws -> SessionCredential? {
        let url = fileURL(for: provider)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SessionCredential.self, from: data)
        } catch {
            throw CredentialStoreError.decodingFailed
        }
    }

    public func delete(_ provider: ProviderID) throws {
        let url = fileURL(for: provider)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw CredentialStoreError.ioFailed
        }
    }

    private func fileURL(for provider: ProviderID) -> URL {
        directoryURL.appendingPathComponent("\(provider.rawValue)-session.json")
    }

    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw CredentialStoreError.ioFailed
        }
    }
}

/// Backward-compatible alias used by older call sites / docs.
public typealias KeychainStore = CredentialStore
public typealias KeychainStoreError = CredentialStoreError
