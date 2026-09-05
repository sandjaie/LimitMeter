import AppKit
import LimitMeterCore
import SwiftUI

struct PopoverView: View {
    @Bindable var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            providerSection(usage: store.claude)
            Divider()
            providerSection(usage: store.codex)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
        .sheet(item: $store.showingSignInFor) { provider in
            SignInView(provider: provider) { credential in
                try store.saveCredential(credential, for: provider)
                Task { await store.refreshAll() }
            }
        }
    }

    private func providerSection(usage: ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProviderBlockView(usage: usage)
            HStack {
                if usage.isSignedIn {
                    Button("Sign out") {
                        try? store.signOut(usage.provider)
                    }
                    .font(.caption)
                } else {
                    Button("Connect…") {
                        store.showingSignInFor = usage.provider
                    }
                    .font(.caption)
                }
                Spacer()
                Text(updatedLabel(for: usage))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Show in menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $store.menuBarProvider) {
                ForEach(ProviderID.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            Spacer()

            Button("Refresh") {
                Task { await store.refreshAll() }
            }
            .disabled(store.isRefreshing)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.caption)
    }

    private func updatedLabel(for usage: ProviderUsage) -> String {
        guard usage.isSignedIn else { return "" }
        let seconds = max(0, Int(Date().timeIntervalSince(usage.fetchedAt)))
        if seconds < 5 {
            return "Updated just now"
        }
        if seconds < 60 {
            return "Updated \(seconds)s ago"
        }
        return "Updated \(seconds / 60)m ago"
    }
}
