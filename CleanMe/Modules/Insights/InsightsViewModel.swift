import Foundation
import Observation

@Observable
final class InsightsViewModel {
    @ObservationIgnored private let insightsStore: InsightsStore
    @ObservationIgnored private let cleanupStore: CleanupStore
    @ObservationIgnored private let workspace: any WorkspaceServicing

    init(insightsStore: InsightsStore, cleanupStore: CleanupStore, workspace: any WorkspaceServicing) {
        self.insightsStore = insightsStore
        self.cleanupStore = cleanupStore
        self.workspace = workspace
    }

    // MARK: - State

    var isAnalyzing: Bool { insightsStore.isAnalyzing }
    var hasReport: Bool { insightsStore.report != nil }

    var locations: [StorageInsight] { insightsStore.report?.locations ?? [] }
    var largestItems: [StorageInsight] { insightsStore.report?.largestItems ?? [] }
    var hiddenFolders: [StorageInsight] { insightsStore.report?.hiddenFolders ?? [] }

    var showsPermissionBanner: Bool { !cleanupStore.hasFullDiskAccess }

    var permissionMessage: String {
        "Without it, app containers and some system folders can't be measured, so sizes will be too low."
    }

    var headline: String {
        guard let report = insightsStore.report else { return "Where does System Data go?" }
        return "\(report.totalMeasured.formatted(.byteCount(style: .file))) measured"
    }

    var subheadline: String {
        if isAnalyzing {
            return "Measuring folders. This can take a few minutes on a full disk."
        }
        guard let report = insightsStore.report else {
            return "Measures the folders macOS counts as System Data, including ones that can't be cleaned automatically."
        }
        return "Analyzed \(report.date.formatted(.relative(presentation: .named))). Nothing on this screen is deleted."
    }

    var analyzeButtonTitle: String { hasReport ? "Analyze Again" : "Analyze" }

    // MARK: - Explanation

    var snapshotNote: String {
        guard let result = cleanupStore.result(for: .timeMachineSnapshots) else {
            return "Local Time Machine snapshots: run a scan on the Overview to count them. macOS doesn't report their size, but they can hold tens of gigabytes."
        }
        let count = result.items.count
        guard count > 0 else { return "Local Time Machine snapshots: none found." }
        let noun = count == 1 ? "snapshot" : "snapshots"
        return "Local Time Machine snapshots: \(count) \(noun). Their size isn't reported by macOS, but it is counted in System Data."
    }

    var explanationNotes: [String] {
        [
            "System Settings counts purgeable space and APFS snapshots as System Data, so the number there is usually larger than what's on disk.",
            snapshotNote,
            "Swap and system caches shrink after a restart. The System Settings number can take a while to update.",
        ]
    }

    // MARK: - Rows

    func sizeText(for insight: StorageInsight) -> String {
        let size = insight.size.formatted(.byteCount(style: .file))
        return insight.isComplete ? size : "≥ \(size)"
    }

    func fraction(for insight: StorageInsight, in list: [StorageInsight]) -> Double {
        guard let largest = list.map(\.size).max(), largest > 0 else { return 0 }
        return Double(insight.size) / Double(largest)
    }

    // MARK: - Actions

    func analyzeTapped() {
        if isAnalyzing {
            insightsStore.cancel()
        } else {
            insightsStore.analyze()
        }
    }

    func reveal(_ insight: StorageInsight) {
        workspace.reveal([insight.url])
    }

    func openFullDiskAccessSettings() {
        workspace.openFullDiskAccessSettings()
    }
}
