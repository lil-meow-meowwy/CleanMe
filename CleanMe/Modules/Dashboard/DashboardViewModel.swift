import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var isConfirmingCleanup = false

    @ObservationIgnored private let store: CleanupStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let workspace: any WorkspaceServicing

    init(store: CleanupStore, settings: SettingsStore, workspace: any WorkspaceServicing) {
        self.store = store
        self.settings = settings
        self.workspace = workspace
    }

    // MARK: - Status

    var diskSpace: DiskSpaceInfo? { store.diskSpace }
    var hasResults: Bool { store.hasResults }
    var isScanning: Bool { store.isScanning }
    var isBusy: Bool { store.isBusy }
    var scanProgress: Double { store.scanProgress }
    var showsPermissionBanner: Bool { !store.hasFullDiskAccess }
    var groups: [CategoryGroup] { CategoryGroup.allCases }

    var reclaimableBytes: Int64 { store.totalReclaimableSize }
    var selectedBytes: Int64 { store.totalSelectedSize }

    var headline: String {
        if isScanning { return "Scanning System Data…" }
        guard hasResults else { return "Find out what's taking up System Data" }
        return "\(reclaimableBytes.formatted(.byteCount(style: .file))) can be cleaned"
    }

    var subheadline: String {
        if isScanning {
            return "Measuring caches, logs, developer files and backups."
        }
        guard let date = store.lastScanDate else {
            return "CleanMe looks at caches, logs, temporary files, developer data, and local backups."
        }
        return "Last scanned \(date.formatted(.relative(presentation: .named)))."
    }

    var scanButtonTitle: String { hasResults ? "Rescan" : "Scan" }

    var selectionSummary: String {
        let count = store.selectedItemCount
        guard count > 0 else { return "Nothing selected" }
        let noun = count == 1 ? "item" : "items"
        return "\(count) \(noun) selected"
    }

    var selectedSizeText: String {
        selectedBytes.formatted(.byteCount(style: .file))
    }

    var canClean: Bool {
        !store.isBusy && store.selectedItemCount > 0
    }

    var permissionMessage: String {
        "Without it, some System Data (like Mail downloads) can't be scanned. Allow CleanMe in System Settings › Privacy & Security › Full Disk Access."
    }

    // MARK: - Category rows

    func sizeText(for category: CleanupCategory) -> String {
        guard let result = store.result(for: category) else { return "—" }
        if result.items.isEmpty { return result.notice == nil ? "Clean" : "Unavailable" }
        if category.hasUnknownItemSizes {
            let noun = result.items.count == 1 ? "snapshot" : "snapshots"
            return "\(result.items.count) \(noun)"
        }
        return result.totalSize.formatted(.byteCount(style: .file))
    }

    func isPending(_ category: CleanupCategory) -> Bool {
        store.isPending(category)
    }

    func selectionState(for category: CleanupCategory) -> SelectionState {
        store.selectionState(for: category)
    }

    func canSelect(_ category: CleanupCategory) -> Bool {
        !(store.result(for: category)?.items.isEmpty ?? true) && !store.isBusy
    }

    func toggle(_ category: CleanupCategory) {
        store.toggleCategory(category)
    }

    // MARK: - Actions

    func scanTapped() {
        if isScanning {
            store.cancelScan()
        } else {
            store.startScan()
        }
    }

    func openFullDiskAccessSettings() {
        workspace.openFullDiskAccessSettings()
    }

    var cleanupPlan: CleanupPlan { store.plan() }

    func cleanTapped() {
        guard canClean else { return }
        if settings.confirmBeforeCleaning {
            isConfirmingCleanup = true
        } else {
            confirmCleanup()
        }
    }

    func confirmCleanup() {
        Task { await store.cleanSelected() }
    }
}
