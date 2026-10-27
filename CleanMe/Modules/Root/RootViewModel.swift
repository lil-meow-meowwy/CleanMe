import Foundation
import Observation

@Observable
final class RootViewModel {
    enum Destination: Hashable {
        case overview
        case insights
        case category(CleanupCategory)
    }

    var selection: Destination? = .overview

    /// Sidebar groups the user collapsed; remembered between launches.
    private(set) var collapsedGroups: Set<CategoryGroup> {
        didSet {
            UserDefaults.standard.set(
                collapsedGroups.map(\.rawValue),
                forKey: AppConstants.DefaultsKeys.collapsedSidebarGroups
            )
        }
    }

    @ObservationIgnored private let dependencies: DependencyContainer
    private var store: CleanupStore { dependencies.store }

    init(dependencies: DependencyContainer) {
        self.dependencies = dependencies
        let stored = UserDefaults.standard.stringArray(forKey: AppConstants.DefaultsKeys.collapsedSidebarGroups) ?? []
        self.collapsedGroups = Set(stored.compactMap(CategoryGroup.init(rawValue:)))
    }

    // MARK: - Sidebar

    var groups: [CategoryGroup] { CategoryGroup.allCases }

    func isExpanded(_ group: CategoryGroup) -> Bool {
        !collapsedGroups.contains(group)
    }

    func setExpanded(_ group: CategoryGroup, _ isExpanded: Bool) {
        if isExpanded {
            collapsedGroups.remove(group)
        } else {
            collapsedGroups.insert(group)
        }
    }

    /// Total size found in a group, shown next to its header.
    func sizeText(for group: CategoryGroup) -> String? {
        let total = group.categories.reduce(Int64(0)) { $0 + store.totalSize(for: $1) }
        return total > 0 ? total.formatted(.byteCount(style: .file)) : nil
    }

    func sizeText(for category: CleanupCategory) -> String? {
        guard let result = store.result(for: category), !result.items.isEmpty else { return nil }
        if category.hasUnknownItemSizes {
            return "\(result.items.count)"
        }
        return result.totalSize.formatted(.byteCount(style: .file))
    }

    func isPending(_ category: CleanupCategory) -> Bool {
        store.isPending(category)
    }

    // MARK: - Global state

    var isCleaning: Bool { store.isCleaning }

    /// Drives the cleanup report sheet.
    var presentedReport: CleanupReport? {
        get { store.lastReport }
        set { if newValue == nil { store.dismissReport() } }
    }

    func onAppear() {
        store.refreshEnvironment()
    }

    func appDidBecomeActive() {
        // The user may have just granted Full Disk Access in System Settings.
        store.refreshEnvironment()
    }

    // MARK: - Child view models

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(store: store, settings: dependencies.settings, workspace: dependencies.workspace)
    }

    func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(
            insightsStore: dependencies.insights,
            cleanupStore: store,
            workspace: dependencies.workspace
        )
    }

    func makeCategoryDetailViewModel(for category: CleanupCategory) -> CategoryDetailViewModel {
        CategoryDetailViewModel(
            category: category,
            store: store,
            settings: dependencies.settings,
            workspace: dependencies.workspace
        )
    }

    func makeReportViewModel(for report: CleanupReport) -> CleanupReportViewModel {
        CleanupReportViewModel(report: report, workspace: dependencies.workspace)
    }
}
