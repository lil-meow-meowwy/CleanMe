import Foundation

nonisolated enum DeletionMode: String, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trash: "Move to Trash"
        case .permanent: "Delete Permanently"
        }
    }

    var explanation: String {
        switch self {
        case .trash:
            "Safer: items can be restored from the Trash. Space is freed once you empty the Trash."
        case .permanent:
            "Frees space immediately. Removed items can't be restored."
        }
    }
}
