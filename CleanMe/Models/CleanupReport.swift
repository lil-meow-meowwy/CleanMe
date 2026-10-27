import Foundation

/// The outcome of a cleanup run.
nonisolated struct CleanupReport: Identifiable, Sendable {
    nonisolated struct Failure: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let reason: String
    }

    let id = UUID()
    let freedBytes: Int64
    let removedItemIDs: Set<ScanItem.ID>
    let failures: [Failure]
    let mode: DeletionMode
    let date: Date

    var removedCount: Int { removedItemIDs.count }
    var hasFailures: Bool { !failures.isEmpty }
}
