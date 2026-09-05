import LimitMeterCore
import SwiftUI

extension LimitSeverity {
    var color: Color {
        switch self {
        case .ok: .green
        case .warn: .yellow
        case .critical: .red
        case .unknown: .secondary
        }
    }
}

enum LimitColorUI {
    static func forRemaining(_ remaining: Double?) -> Color {
        LimitColor.severity(for: remaining).color
    }
}
