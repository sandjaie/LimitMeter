import Foundation

public enum LimitColor {
    /// remaining ≥40 ok, 15..<40 warn, <15 critical; nil → unknown
    public static func severity(for remaining: Double?) -> LimitSeverity {
        guard let remaining else { return .unknown }
        if remaining >= 40 {
            return .ok
        }
        if remaining >= 15 {
            return .warn
        }
        return .critical
    }
}

public enum LimitSeverity: Equatable, Sendable {
    case ok
    case warn
    case critical
    case unknown
}
