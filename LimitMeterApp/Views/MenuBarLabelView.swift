import AppKit
import LimitMeterCore
import SwiftUI

/// MenuBarExtra forces template (monochrome) rendering on Text/HStack.
/// Render a non-template NSImage so green / amber / red percentages show in the bar.
struct MenuBarLabelView: View {
    let usage: ProviderUsage

    var body: some View {
        Image(nsImage: MenuBarLabelRenderer.image(for: usage))
            .renderingMode(.original)
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        usage.isSignedIn
            ? UsageFormatting.menuBarText(usage: usage)
            : "\(usage.provider.displayName) · Connect"
    }
}

enum MenuBarLabelRenderer {
    static func image(for usage: ProviderUsage) -> NSImage {
        let attributed = attributedTitle(for: usage)
        let size = attributed.size()
        let padding = NSSize(width: 2, height: 1)
        let imageSize = NSSize(
            width: ceil(size.width) + padding.width * 2,
            height: max(16, ceil(size.height) + padding.height * 2)
        )
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        attributed.draw(
            at: NSPoint(
                x: padding.width,
                y: (imageSize.height - size.height) / 2
            )
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func attributedTitle(for usage: ProviderUsage) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let base = NSMutableAttributedString()

        let icon = NSTextAttachment()
        icon.image = brandIcon(for: usage.provider, size: 12)
        if let image = icon.image {
            icon.bounds = CGRect(x: 0, y: -1.5, width: image.size.width, height: image.size.height)
        }
        base.append(NSAttributedString(attachment: icon))
        base.append(NSAttributedString(
            string: " ",
            attributes: [.font: font]
        ))

        if !usage.isSignedIn {
            base.append(NSAttributedString(
                string: "\(usage.provider.displayName) · Connect",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            ))
            return base
        }

        appendWindow(
            to: base,
            label: "5hr",
            window: usage.fiveHour,
            font: font
        )
        base.append(NSAttributedString(
            string: " | ",
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        appendWindow(
            to: base,
            label: "7D",
            window: usage.sevenDay,
            font: font
        )
        return base
    }

    private static func appendWindow(
        to output: NSMutableAttributedString,
        label: String,
        window: LimitWindow?,
        font: NSFont
    ) {
        let secondary: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        output.append(NSAttributedString(string: "\(label): ", attributes: secondary))

        guard let window else {
            output.append(NSAttributedString(string: "—", attributes: secondary))
            return
        }

        let percentColor = nsColor(for: window.remainingPercent)
        output.append(NSAttributedString(
            string: UsageFormatting.percentText(window.remainingPercent),
            attributes: [
                .font: font,
                .foregroundColor: percentColor,
            ]
        ))
        output.append(NSAttributedString(
            string: " · \(UsageFormatting.relativeCountdown(until: window.resetsAt))",
            attributes: secondary
        ))
    }

    private static func nsColor(for remaining: Double) -> NSColor {
        switch LimitColor.severity(for: remaining) {
        case .ok:
            NSColor.systemGreen
        case .warn:
            NSColor.systemYellow
        case .critical:
            NSColor.systemRed
        case .unknown:
            NSColor.secondaryLabelColor
        }
    }

    private static func brandIcon(for provider: ProviderID, size: CGFloat) -> NSImage {
        ProviderLogo.nsImage(for: provider, size: size, invertForDarkMenuBar: true)
    }
}
