import LimitMeterCore
import SwiftUI

struct SignInView: View {
    let provider: ProviderID
    var onSave: (SessionCredential) throws -> Void

    @State private var token = ""
    @State private var accountID = ""
    @State private var errorMessage: String?
    @State private var showAdvanced = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect \(provider.displayName)")
                .font(.headline)
            Text(instructions)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            primaryImportButton

            if showAdvanced {
                Divider()
                Text("Advanced (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(tokenPlaceholder, text: $token)
                    .textFieldStyle(.roundedBorder)
                TextField(accountPlaceholder, text: $accountID)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Save pasted credentials") { save() }
                        .disabled(!canSave)
                }
            } else {
                Button("Paste credentials instead…") {
                    showAdvanced = true
                }
                .font(.caption)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    @ViewBuilder
    private var primaryImportButton: some View {
        switch provider {
        case .claude:
            Button(ClaudeCodeAuth.isAvailable ? "Use Claude Code login" : "Claude Code login not found") {
                importClaudeCode()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!ClaudeCodeAuth.isAvailable)
        case .codex:
            Button(CodexUsageClient
                .credentialFromCodexAuthFile() != nil ? "Use Codex CLI login" : "Codex CLI login not found") {
                    importCodexAuthFile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(CodexUsageClient.credentialFromCodexAuthFile() == nil)
        }
    }

    private var canSave: Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if provider == .claude, showAdvanced {
            // OAuth token alone is enough; org UUID only for cookie mode.
            return true
        }
        return true
    }

    private var instructions: String {
        switch provider {
        case .claude:
            "If you use Claude Code with a Pro/Max subscription, LimitMeter can reuse that login. "
                + "No API key or browser cookie paste needed."
        case .codex:
            "If you use the Codex CLI, LimitMeter can reuse ~/.codex/auth.json. No manual token paste needed."
        }
    }

    private var tokenPlaceholder: String {
        switch provider {
        case .claude: "OAuth access token or sessionKey cookie"
        case .codex: "Bearer access token"
        }
    }

    private var accountPlaceholder: String {
        switch provider {
        case .claude: "Leave blank for OAuth, or org UUID for cookie mode"
        case .codex: "ChatGPT account id (optional)"
        }
    }

    private func importClaudeCode() {
        do {
            guard let credential = try ClaudeCodeAuth.loadCredential() else {
                errorMessage = "No Claude Code login found. Open Claude Code and sign in once, then try again."
                return
            }
            try onSave(credential)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importCodexAuthFile() {
        guard let credential = CodexUsageClient.credentialFromCodexAuthFile() else {
            errorMessage = "No ~/.codex/auth.json found"
            return
        }
        do {
            try onSave(credential)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAccount = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
            let credential = if provider == .claude, trimmedAccount.isEmpty {
                SessionCredential(token: trimmedToken, accountID: "oauth")
            } else {
                SessionCredential(
                    token: trimmedToken,
                    accountID: trimmedAccount.isEmpty ? nil : trimmedAccount
                )
            }
            try onSave(credential)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
