import Foundation

/// How careful the user should be before removing a category.
nonisolated enum RiskLevel: Int, Comparable, Sendable {
    case safe
    case review
    case caution

    var title: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .caution: "Caution"
        }
    }

    var explanation: String {
        switch self {
        case .safe: "Regenerated automatically. Safe to remove."
        case .review: "Usually safe, but check the contents first."
        case .caution: "Can't be regenerated. Remove only what you no longer need."
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
