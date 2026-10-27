import Foundation
import Observation

/// Single source of truth for scan results and selection, shared by all view models.
@Observable
final class CleanupStore {
    enum Phase: Equatable {
        case idle
        case scanning(completed: Int, total: Int)
        case cleaning
        case ready
    }

    private(set) var phase: Phase = .idle
    private(set) var results: [CleanupCategory: CategoryScanResult] = [:]
    private(set) var selectedItemIDs: [CleanupCategory: Set<ScanItem.ID>] = [:]
    private(set) var diskSpace: DiskSpaceInfo?
    private(set) var hasFullDiskAccess = true
    private(set) var lastScanDate: Date?
    private(set) var lastReport: CleanupReport?

    @ObservationIgnored private let scanner: any FileScanning
    @ObservationIgnored private let cleaner: any FileCleaning
    @ObservationIgnored private let diskSpaceProvider: any DiskSpaceProviding
    @ObservationIgnored private let permissionChecker: any PermissionChecking
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    init(
        scanner: any FileScanning,
        cleaner: any FileCleaning,
        diskSpaceProvider: any DiskSpaceProviding,
        permissionChecker: any PermissionChecking,
        settings: SettingsStore
    ) {
        self.scanner = scanner
        self.cleaner = cleaner
        self.diskSpaceProvider = diskSpaceProvider
        self.permissionChecker = permissionChecker
        self.settings = settings
    }

    // MARK: - State

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var isCleaning: Bool { phase == .cleaning }
    var isBusy: Bool { isScanning || isCleaning }
    var hasResults: Bool { !results.isEmpty }

    var scanProgress: Double {
        guard case let .scanning(completed, total) = phase, total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    func refreshEnvironment() {
        diskSpace = diskSpaceProvider.currentDiskSpace()
        hasFullDiskAccess = permissionChecker.hasFullDiskAccess()
    }

    // MARK: - Scanning

    func startScan() {
        guard !isCleaning else { return }
        scanTask?.cancel()
        refreshEnvironment()

        let categories = CleanupCategory.allCases
        let options = settings.scanOptions
        let scanner = self.scanner

        results = [:]
        selectedItemIDs = [:]
        phase = .scanning(completed: 0, total: categories.count)

        scanTask = Task {
            await withTaskGroup(of: CategoryScanResult.self) { group in
                for category in categories {
                    group.addTask { await scanner.scan(category, options: options) }
                }

                var completed = 0
                for await result in group {
                    guard !Task.isCancelled else { break }
                    completed += 1
                    results[result.category] = result
                    if result.category.isSelectedByDefault {
                        selectedItemIDs[result.category] = Set(result.items.map(\.id))
                    }
                    phase = .scanning(completed: completed, total: categories.count)
                }
            }

            if Task.isCancelled {
                phase = results.isEmpty ? .idle : .ready
            } else {
                lastScanDate = .now
                phase = .ready
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    // MARK: - Queries

    func result(for category: CleanupCategory) -> CategoryScanResult? {
        results[category]
    }

    func isPending(_ category: CleanupCategory) -> Bool {
        isScanning && results[category] == nil
    }

    func totalSize(for category: CleanupCategory) -> Int64 {
        results[category]?.totalSize ?? 0
    }

    func selectedItems(in category: CleanupCategory) -> [ScanItem] {
        guard let result = results[category], let ids = selectedItemIDs[category], !ids.isEmpty else { return [] }
        return result.items.filter { ids.contains($0.id) }
    }

    func selectedSize(for category: CleanupCategory) -> Int64 {
        selectedItems(in: category).reduce(0) { $0 + ($1.size ?? 0) }
    }

    func selectionState(for category: CleanupCategory) -> SelectionState {
        let total = results[category]?.items.count ?? 0
        let selected = selectedItemIDs[category]?.count ?? 0
        if total == 0 || selected == 0 { return .none }
        return selected >= total ? .all : .partial
    }

    func isSelected(_ item: ScanItem, in category: CleanupCategory) -> Bool {
        selectedItemIDs[category]?.contains(item.id) ?? false
    }

    var totalReclaimableSize: Int64 {
        results.values.reduce(0) { $0 + $1.totalSize }
    }

    var totalSelectedSize: Int64 {
        CleanupCategory.allCases.reduce(0) { $0 + selectedSize(for: $1) }
    }

    var selectedItemCount: Int {
        selectedItemIDs.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Selection

    func setCategory(_ category: CleanupCategory, selected: Bool) {
        guard let result = results[category] else { return }
        selectedItemIDs[category] = selected ? Set(result.items.map(\.id)) : []
    }

    func toggleCategory(_ category: CleanupCategory) {
        setCategory(category, selected: selectionState(for: category) != .all)
    }

    func toggleItem(_ item: ScanItem, in category: CleanupCategory) {
        var ids = selectedItemIDs[category] ?? []
        if ids.contains(item.id) {
            ids.remove(item.id)
        } else {
            ids.insert(item.id)
        }
        selectedItemIDs[category] = ids
    }

    // MARK: - Cleaning

    /// - Parameter categories: limit to these categories, or `nil` for everything selected.
    func plan(for categories: Set<CleanupCategory>? = nil) -> CleanupPlan {
        let selection = itemsToClean(in: categories)
        let items = selection.values.flatMap { $0 }
        return CleanupPlan(
            itemCount: items.count,
            totalBytes: items.reduce(0) { $0 + ($1.size ?? 0) },
            requiresAdministrator: selection.keys.contains { $0.requiresAdministrator },
            containsUnknownSizes: selection.keys.contains { $0.hasUnknownItemSizes },
            mode: settings.deletionMode
        )
    }

    func cleanSelected(in categories: Set<CleanupCategory>? = nil) async {
        guard !isBusy else { return }
        let selection = itemsToClean(in: categories)
        guard !selection.isEmpty else { return }

        phase = .cleaning
        let report = await cleaner.clean(selection, mode: settings.deletionMode)

        for category in results.keys {
            results[category]?.items.removeAll { report.removedItemIDs.contains($0.id) }
            selectedItemIDs[category]?.subtract(report.removedItemIDs)
        }

        lastReport = report
        phase = .ready
        refreshEnvironment()
    }

    func dismissReport() {
        lastReport = nil
    }

    private func itemsToClean(in categories: Set<CleanupCategory>?) -> [CleanupCategory: [ScanItem]] {
        var selection: [CleanupCategory: [ScanItem]] = [:]
        for category in CleanupCategory.allCases where categories?.contains(category) ?? true {
            let items = selectedItems(in: category)
            if !items.isEmpty {
                selection[category] = items
            }
        }
        return selection
    }
}
