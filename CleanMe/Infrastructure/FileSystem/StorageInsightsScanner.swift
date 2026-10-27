import Foundation

nonisolated protocol StorageInsightsScanning: Sendable {
    func analyze() async -> StorageInsightsReport
}

/// Measures the folders listed in `InsightLocations` plus hidden folders in the home
/// directory. Read-only: nothing here is ever deleted.
nonisolated struct StorageInsightsScanner: StorageInsightsScanning {
    private nonisolated struct Partial: Sendable {
        var locations: [StorageInsight] = []
        var children: [StorageInsight] = []
        var hidden: [StorageInsight] = []
    }

    func analyze() async -> StorageInsightsReport {
        let locations = InsightLocations.all

        let merged = await withTaskGroup(of: Partial.self) { group in
            for location in locations {
                group.addTask { await BackgroundWork.run { Self.measure(location) } }
            }
            group.addTask { await BackgroundWork.run { Self.measureHiddenFolders() } }

            var result = Partial()
            for await partial in group {
                result.locations += partial.locations
                result.children += partial.children
                result.hidden += partial.hidden
            }
            return result
        }

        return StorageInsightsReport(
            locations: merged.locations.sorted { $0.size > $1.size },
            largestItems: Array(merged.children.sorted { $0.size > $1.size }.prefix(AppConstants.Insights.largestItemsLimit)),
            hiddenFolders: merged.hidden.sorted { $0.size > $1.size },
            date: .now
        )
    }

    // MARK: - Measuring

    private static func measure(_ location: InsightLocation) -> Partial {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: location.url.path) else { return Partial() }

        guard location.breaksDownChildren else {
            let measurement = FileSizeCalculator.measure(location.url)
            return Partial(locations: [insight(for: location, size: measurement.bytes, isComplete: measurement.isComplete)])
        }

        // Measure each child once; the parent is the sum, so nothing is enumerated twice.
        guard let children = try? fileManager.contentsOfDirectory(
            at: location.url,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return Partial(locations: [insight(for: location, size: 0, isComplete: false)])
        }

        var childInsights: [StorageInsight] = []
        var total: Int64 = 0
        var isComplete = true

        for child in children {
            guard !Task.isCancelled else { break }
            let measurement = FileSizeCalculator.measure(child)
            total += measurement.bytes
            isComplete = isComplete && measurement.isComplete
            guard measurement.bytes > 0 else { continue }

            childInsights.append(
                StorageInsight(
                    title: child.lastPathComponent,
                    detail: SystemDataLocations.abbreviated(location.url),
                    systemImage: location.systemImage,
                    url: child,
                    size: measurement.bytes,
                    isComplete: measurement.isComplete,
                    relatedCategory: nil
                )
            )
        }

        return Partial(
            locations: [insight(for: location, size: total, isComplete: isComplete)],
            children: childInsights
        )
    }

    /// `~/.npm`, `~/.docker`, `~/.gradle`… macOS counts these as System Data too.
    private static func measureHiddenFolders() -> Partial {
        let home = SystemDataLocations.home
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: home.path) else { return Partial() }

        var hidden: [StorageInsight] = []
        for name in names where name.hasPrefix(".") && name != ".Trash" {
            guard !Task.isCancelled else { break }
            let url = home.appending(path: name)
            let measurement = FileSizeCalculator.measure(url)
            guard measurement.bytes >= AppConstants.Insights.hiddenFolderMinimumSize else { continue }

            hidden.append(
                StorageInsight(
                    title: "~/\(name)",
                    detail: "Hidden folder in your home",
                    systemImage: "eye.slash",
                    url: url,
                    size: measurement.bytes,
                    isComplete: measurement.isComplete,
                    relatedCategory: nil
                )
            )
        }
        return Partial(hidden: hidden)
    }

    private static func insight(for location: InsightLocation, size: Int64, isComplete: Bool) -> StorageInsight {
        StorageInsight(
            title: location.title,
            detail: location.detail,
            systemImage: location.systemImage,
            url: location.url,
            size: size,
            isComplete: isComplete,
            relatedCategory: location.relatedCategory
        )
    }
}
