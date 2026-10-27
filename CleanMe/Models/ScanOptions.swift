import Foundation

nonisolated struct ScanOptions: Sendable {
    /// Temporary files modified more recently than this are left alone.
    var temporaryFileMinimumAge: TimeInterval
}
