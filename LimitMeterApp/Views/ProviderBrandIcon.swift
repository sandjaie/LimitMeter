import AppKit
import CoreImage
import LimitMeterCore
import SwiftUI

enum ProviderLogo {
    static func nsImage(for provider: ProviderID, size: CGFloat, invertForDarkMenuBar: Bool = false) -> NSImage {
        let name = provider.logoAssetName
        let loaded = loadImage(named: name)

        guard var source = loaded else {
            return NSImage(size: NSSize(width: size, height: size))
        }

        if invertForDarkMenuBar, provider == .codex, let inverted = inverted(source) {
            source = inverted
        }

        let output = NSImage(size: NSSize(width: size, height: size))
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        output.unlockFocus()
        output.isTemplate = false
        return output
    }

    private static func loadImage(named name: String) -> NSImage? {
        if let image = Bundle.module.image(forResource: name) {
            return image
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent("LimitMeter_LimitMeter.bundle")
            .appendingPathComponent("\(name).png"),
            let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private static func inverted(_ image: NSImage) -> NSImage? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let ciImage = CIImage(bitmapImageRep: bitmap) else {
            return nil
        }
        let filter = CIFilter(name: "CIColorInvert")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter?.outputImage else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let result = NSImage(size: rep.size)
        result.addRepresentation(rep)
        return result
    }
}

struct ProviderBrandIcon: View {
    let provider: ProviderID
    var size: CGFloat = 16
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: ProviderLogo.nsImage(
            for: provider,
            size: size,
            invertForDarkMenuBar: provider == .codex && colorScheme == .dark
        ))
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension ProviderID {
    var logoAssetName: String {
        switch self {
        case .claude: "ClaudeLogo"
        case .codex: "CodexLogo"
        }
    }
}
