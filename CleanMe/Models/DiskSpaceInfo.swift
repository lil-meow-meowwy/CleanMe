import Foundation

nonisolated struct DiskSpaceInfo: Equatable, Sendable {
    let volumeName: String
    let totalCapacity: Int64
    let availableCapacity: Int64

    var usedCapacity: Int64 {
        max(totalCapacity - availableCapacity, 0)
    }

    func fraction(of bytes: Int64) -> Double {
        guard totalCapacity > 0 else { return 0 }
        return min(max(Double(bytes) / Double(totalCapacity), 0), 1)
    }
}
