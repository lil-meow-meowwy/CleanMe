import Foundation
import Observation

@Observable
final class CategoryDetailViewModel {
    enum SortOption: String, CaseIterable, Identifiable {
        case size = "Size"
        case name = "Name"
        case date = "Date Modified"

        var id: String { rawValue }
    }

    let category: CleanupCategory
    var searchText = ""
    var sortOption: SortOption = .size
    var isConfirmingCleanup = false

    @ObservationIgnored private let store: CleanupStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let workspace: any WorkspaceServicing

    init(
        category: CleanupCategory,
        store: CleanupStore,
        settings: SettingsStore,
        workspace: any WorkspaceServicing
    ) {
        self.category = category
        self.store = store
        self.settings = settings
        self.workspace = workspace
        if category.hasUnknownItemSizes {
            sortOption = .date
        }
    }

    // MARK: - State

    private var result: CategoryScanResult? { store.result(for: category) }

    var isLoading: Bool { store.isPending(category) }
    var hasResult: Bool { result != nil }
    var isBusy: Bool { store.isBusy }
    var isEmpty: Bool { result?.items.isEmpty ?? true }
    var isFiltering: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var items: [ScanItem] {
        guard let result else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty
            ? result.items
            : result.items.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || ($0.detail?.localizedCaseInsensitiveContains(query) ?? false)
            }

        switch sortOption {
        case .size:
            return filtered.sorted { ($0.size ?? -1) > ($1.size ?? -1) }
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            return filtered.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        }
    }

    var totalSizeText: String {
        guard let result else { return "Not scanned" }
        if category.hasUnknownItemSizes {
            let noun = result.items.count == 1 ? "snapshot" : "snapshots"
            return "\(result.items.count) \(noun)"
        }
        return result.totalSize.formatted(.byteCount(style: .file))
    }

    var locationsText: String {
        SystemDataLocations.displayPaths(for: category).joined(separator: "\n")
    }

    var canRevealLocation: Bool { SystemDataLocations.revealDirectory(for: category) != nil }

    /// Informational message from the scan, e.g. "Docker isn't running".
    var notice: String? { result?.notice }

    // MARK: - Permissions

    var showsPermissionBanner: Bool {
        if category.requiresFullDiskAccess && !store.hasFullDiskAccess { return true }
        return !(result?.inaccessiblePaths.isEmpty ?? true)
    }

    var permissionMessage: String {
        "Some locations in this category couldn't be read. Allow CleanMe in System Settings › Privacy & Security › Full Disk Access, then scan again."
    }

    func openFullDiskAccessSettings() {
        workspace.openFullDiskAccessSettings()
    }

    // MARK: - Selection

    var selectionState: SelectionState { store.selectionState(for: category) }

    func isSelected(_ item: ScanItem) -> Bool {
        store.isSelected(item, in: category)
    }

    func toggle(_ item: ScanItem) {
        store.toggleItem(item, in: category)
    }

    func toggleAll() {
        store.toggleCategory(category)
    }

    var selectionSummary: String {
        let count = store.selectedItems(in: category).count
        guard count > 0 else { return "Nothing selected" }
        let noun = count == 1 ? "item" : "items"
        return "\(count) \(noun) selected"
    }

    var selectedSizeText: String {
        if category.hasUnknownItemSizes { return "Size unknown" }
        return store.selectedSize(for: category).formatted(.byteCount(style: .file))
    }

    var canClean: Bool {
        !store.isBusy && !store.selectedItems(in: category).isEmpty
    }

    // MARK: - Row formatting

    func sizeText(for item: ScanItem) -> String {
        item.size?.formatted(.byteCount(style: .file)) ?? "Unknown"
    }

    func dateText(for item: ScanItem) -> String {
        item.modificationDate?.formatted(date: .abbreviated, time: .shortened) ?? "—"
    }

    // MARK: - Actions

    func reveal(_ item: ScanItem) {
        guard let url = item.url else { return }
        workspace.reveal([url])
    }

    func openLocation() {
        guard let directory = SystemDataLocations.revealDirectory(for: category) else { return }
        workspace.open(directory)
    }

    func scan() {
        store.startScan()
    }

    var cleanupPlan: CleanupPlan { store.plan(for: [category]) }

    func cleanTapped() {
        guard canClean else { return }
        if settings.confirmBeforeCleaning {
            isConfirmingCleanup = true
        } else {
            confirmCleanup()
        }
    }

    func confirmCleanup() {
        let category = category
        Task { await store.cleanSelected(in: [category]) }
    }
}
