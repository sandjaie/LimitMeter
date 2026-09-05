import LimitMeterCore
import SwiftUI

struct ProviderBlockView: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProviderBrandIcon(provider: usage.provider, size: 18)
                Text(usage.provider.displayName)
                    .font(.headline)
                Spacer()
                trailingBadge
            }

            HStack(spacing: 8) {
                windowTile(title: "5hr", window: usage.fiveHour)
                windowTile(title: "7D", window: usage.sevenDay)
            }

            statusRow
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if usage.isSignedIn, let plan = usage.planLabel {
            Text(plan)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !usage.isSignedIn {
            Text("Not connected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch usage.status {
        case .ok:
            if usage.dataSource == .localCache {
                Text("From Claude Code cache")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .needsAuth:
            Text("Connect your account to load live 5hr / 7D limits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .error(message):
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FetchErrorCopy.isRateLimitedMessage(message) ? Color.orange : Color.red)
                if usage.fiveHour != nil || usage.sevenDay != nil {
                    Text("Showing last known values.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func windowTile(title: String, window: LimitWindow?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let window {
                Text("\(UsageFormatting.percentText(window.remainingPercent)) left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(LimitColorUI.forRemaining(window.remainingPercent))
                Text("resets in \(UsageFormatting.relativeCountdown(until: window.resetsAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
