import Foundation

/// Tri-state selection for a category (all / some / none of its items).
nonisolated enum SelectionState: Sendable {
    case none
    case partial
    case all
}
