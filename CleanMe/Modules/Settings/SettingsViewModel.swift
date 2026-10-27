import Foundation
import Observation

@Observable
final class SettingsViewModel {
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let workspace: any WorkspaceServicing

    init(settings: SettingsStore, workspace: any WorkspaceServicing) {
        self.settings = settings
        self.workspace = workspace
    }

    var deletionModes: [DeletionMode] { DeletionMode.allCases }
    var temporaryFileAgeRange: ClosedRange<Int> { AppConstants.Defaults.temporaryFileMinimumAgeRange }

    var deletionMode: DeletionMode {
        get { settings.deletionMode }
        set { settings.deletionMode = newValue }
    }

    var temporaryFileMinimumAgeDays: Int {
        get { settings.temporaryFileMinimumAgeDays }
        set { settings.temporaryFileMinimumAgeDays = newValue }
    }

    var confirmBeforeCleaning: Bool {
        get { settings.confirmBeforeCleaning }
        set { settings.confirmBeforeCleaning = newValue }
    }

    func openFullDiskAccessSettings() {
        workspace.openFullDiskAccessSettings()
    }
}
