import Foundation

/// Builds and owns the app's long-lived services. Created once in `CleanMeApp`.
final class DependencyContainer {
    let settings: SettingsStore
    let store: CleanupStore
    let insights: InsightsStore
    let workspace: any WorkspaceServicing

    init() {
        let shell = ShellCommandRunner()
        let snapshots = TimeMachineService(shell: shell)
        let simulators = SimulatorService(shell: shell)
        let tools = DeveloperToolsService(shell: shell)
        let settings = SettingsStore()

        self.settings = settings
        self.workspace = WorkspaceService()
        self.insights = InsightsStore(scanner: StorageInsightsScanner())
        self.store = CleanupStore(
            scanner: FileScanner(snapshotProvider: snapshots, simulators: simulators, tools: tools),
            cleaner: FileCleaner(
                privilegedRunner: AppleScriptPrivilegedRunner(shell: shell),
                snapshotProvider: snapshots,
                simulators: simulators,
                tools: tools
            ),
            diskSpaceProvider: DiskSpaceService(),
            permissionChecker: PermissionService(),
            settings: settings
        )
    }
}
