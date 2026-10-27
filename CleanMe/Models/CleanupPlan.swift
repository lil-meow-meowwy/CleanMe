import Foundation

/// A summary of what a cleanup is about to do, used for the confirmation dialog.
nonisolated struct CleanupPlan: Sendable {
    let itemCount: Int
    let totalBytes: Int64
    let requiresAdministrator: Bool
    let containsUnknownSizes: Bool
    let mode: DeletionMode

    var isEmpty: Bool { itemCount == 0 }

    var title: String {
        "Clean \(totalBytes.formatted(.byteCount(style: .file)))?"
    }

    var message: String {
        let action = mode == .trash ? "moved to the Trash" : "permanently deleted"
        let noun = itemCount == 1 ? "item" : "items"
        var lines = ["\(itemCount) \(noun) will be \(action)."]
        if requiresAdministrator {
            lines.append("Some items belong to the system. You'll be asked for an administrator password, and those items are deleted permanently.")
        }
        if containsUnknownSizes {
            lines.append("macOS doesn't report the size of local Time Machine snapshots, so you may free more space than shown.")
        }
        return lines.joined(separator: "\n\n")
    }
}
