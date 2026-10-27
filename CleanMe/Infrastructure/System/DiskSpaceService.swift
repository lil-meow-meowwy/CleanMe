import Foundation

nonisolated protocol DiskSpaceProviding: Sendable {
    func currentDiskSpace() -> DiskSpaceInfo?
}

nonisolated struct DiskSpaceService: DiskSpaceProviding {
    func currentDiskSpace() -> DiskSpaceInfo? {
        let rootVolume = URL(filePath: "/")
        guard let values = try? rootVolume.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]),
            let total = values.volumeTotalCapacity
        else { return nil }

        return DiskSpaceInfo(
            volumeName: values.volumeName ?? "Macintosh HD",
            totalCapacity: Int64(total),
            availableCapacity: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }
}
