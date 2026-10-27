import Foundation

/// Everything found for one category during a scan.
nonisolated struct CategoryScanResult: Identifiable, Sendable {
    let category: CleanupCategory
    var items: [ScanItem]
    /// Locations that exist but couldn't be read (usually missing Full Disk Access).
    var inaccessiblePaths: [String]
    /// Informational message, e.g. "Docker isn't running".
    var notice: String? = nil

    var id: CleanupCategory { category }

    var totalSize: Int64 {
        items.reduce(0) { $0 + ($1.size ?? 0) }
    }
}
