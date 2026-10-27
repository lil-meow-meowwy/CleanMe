import Foundation
import Observation

/// User preferences backed by `UserDefaults`.
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    var deletionMode: DeletionMode {
        didSet { defaults.set(deletionMode.rawValue, forKey: AppConstants.DefaultsKeys.deletionMode) }
    }

    var temporaryFileMinimumAgeDays: Int {
        didSet { defaults.set(temporaryFileMinimumAgeDays, forKey: AppConstants.DefaultsKeys.temporaryFileMinimumAgeDays) }
    }

    var confirmBeforeCleaning: Bool {
        didSet { defaults.set(confirmBeforeCleaning, forKey: AppConstants.DefaultsKeys.confirmBeforeCleaning) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            AppConstants.DefaultsKeys.deletionMode: AppConstants.Defaults.deletionMode.rawValue,
            AppConstants.DefaultsKeys.temporaryFileMinimumAgeDays: AppConstants.Defaults.temporaryFileMinimumAgeDays,
            AppConstants.DefaultsKeys.confirmBeforeCleaning: AppConstants.Defaults.confirmBeforeCleaning,
        ])

        let storedMode = defaults.string(forKey: AppConstants.DefaultsKeys.deletionMode) ?? ""
        deletionMode = DeletionMode(rawValue: storedMode) ?? AppConstants.Defaults.deletionMode
        temporaryFileMinimumAgeDays = defaults.integer(forKey: AppConstants.DefaultsKeys.temporaryFileMinimumAgeDays)
        confirmBeforeCleaning = defaults.bool(forKey: AppConstants.DefaultsKeys.confirmBeforeCleaning)
    }

    var scanOptions: ScanOptions {
        ScanOptions(
            temporaryFileMinimumAge: TimeInterval(temporaryFileMinimumAgeDays) * AppConstants.Scanning.secondsPerDay
        )
    }
}
