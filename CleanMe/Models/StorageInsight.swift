import Foundation

/// A folder the Storage Breakdown measures, described in `InsightLocations`.
nonisolated struct InsightLocation: Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let url: URL
    /// A cleanup category that removes part of this folder, if any.
    let relatedCategory: CleanupCategory?
    /// Also measure each child separately and list the largest ones.
    let breaksDownChildren: Bool
}

/// One measured folder in the Storage Breakdown.
nonisolated struct StorageInsight: Identifiable, Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let url: URL
    let size: Int64
    /// `false` when part of the folder couldn't be read (size is a lower bound).
    let isComplete: Bool
    let relatedCategory: CleanupCategory?

    var id: String { url.path }
}

nonisolated struct StorageInsightsReport: Sendable {
    /// Known System Data locations.
    var locations: [StorageInsight] = []
    /// Largest individual folders inside app data locations.
    var largestItems: [StorageInsight] = []
    /// Hidden folders in the home directory (`~/.something`).
    var hiddenFolders: [StorageInsight] = []
    let date: Date

    var totalMeasured: Int64 {
        locations.reduce(0) { $0 + $1.size } + hiddenFolders.reduce(0) { $0 + $1.size }
    }
}
