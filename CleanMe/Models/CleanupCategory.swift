import Foundation

/// A logical bucket of macOS "System Data" that can be scanned and cleaned.
/// The order of cases is the order shown in the UI.
nonisolated enum CleanupCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Caches & Logs
    case userCaches
    case appContainerCaches
    case appSupportCaches
    case perUserSystemCaches
    case systemCaches
    case userLogs
    case systemLogs
    case unifiedLogs
    case temporaryFiles
    case mailDownloads
    // Developer
    case xcodeDerivedData
    case xcodePreviews
    case xcodeLeftovers
    case xcodeArchives
    case deviceSupport
    case simulatorDevices
    case simulatorRuntimes
    case simulatorCaches
    case packageManagerCaches
    case homebrew
    case docker
    // Backups & Installers
    case iosBackups
    case deviceSoftwareUpdates
    case macOSInstallers
    case timeMachineSnapshots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userCaches: "User Caches"
        case .appContainerCaches: "App Container Caches"
        case .appSupportCaches: "Browser & App Caches"
        case .perUserSystemCaches: "System Cache Folder"
        case .systemCaches: "System Caches"
        case .userLogs: "User Logs"
        case .systemLogs: "System Logs"
        case .unifiedLogs: "Unified Logs"
        case .temporaryFiles: "Temporary Files"
        case .mailDownloads: "Mail Downloads"
        case .xcodeDerivedData: "Xcode Derived Data"
        case .xcodePreviews: "Xcode Previews"
        case .xcodeLeftovers: "Xcode Leftovers"
        case .xcodeArchives: "Xcode Archives"
        case .deviceSupport: "Device Support Files"
        case .simulatorDevices: "Simulator Devices"
        case .simulatorRuntimes: "Simulator Runtimes"
        case .simulatorCaches: "Simulator Caches"
        case .packageManagerCaches: "Package Caches"
        case .homebrew: "Homebrew"
        case .docker: "Docker"
        case .iosBackups: "iPhone & iPad Backups"
        case .deviceSoftwareUpdates: "Device Software Updates"
        case .macOSInstallers: "macOS Installers"
        case .timeMachineSnapshots: "Time Machine Snapshots"
        }
    }

    var summary: String {
        switch self {
        case .userCaches:
            "Cached data created by apps. Apps rebuild it when needed."
        case .appContainerCaches:
            "Caches of sandboxed (App Store) apps, stored inside their containers. Folder contents are removed, the folders stay."
        case .appSupportCaches:
            "Cache folders that browsers and Electron apps (Chrome, Slack, Teams, VS Code…) keep in Application Support. Quit those apps first."
        case .perUserSystemCaches:
            "Your private macOS cache folder (/var/folders/…/C): clang module caches, icon and font caches. Rebuilt automatically."
        case .systemCaches:
            "Caches shared by all users. Requires an administrator password."
        case .userLogs:
            "Log files and crash reports written by apps."
        case .systemLogs:
            "System-wide log files. Requires an administrator password."
        case .unifiedLogs:
            "The macOS unified log archive, cleared with `log erase`. Requires an administrator password."
        case .temporaryFiles:
            "Leftover temporary files that apps no longer use."
        case .mailDownloads:
            "Attachments that Mail downloaded for preview."
        case .xcodeDerivedData:
            "Build products and indexes. Xcode regenerates them on the next build."
        case .xcodePreviews:
            "Simulator devices and caches created for SwiftUI previews and playgrounds. Rebuilt on demand."
        case .xcodeLeftovers:
            "Documentation cache, device logs and old build products. Re-created when needed."
        case .xcodeArchives:
            "App archives created for distribution. Removing them deletes their dSYMs."
        case .deviceSupport:
            "Debug symbols copied from connected devices. Re-downloaded when a device connects."
        case .simulatorDevices:
            "Simulators together with the apps and data installed on them. Removed with simctl."
        case .simulatorRuntimes:
            "iOS, watchOS, tvOS and visionOS runtimes. Re-download them in Xcode › Settings › Components."
        case .simulatorCaches:
            "Caches used by the Simulator runtimes."
        case .packageManagerCaches:
            "Download caches of npm, Gradle, CocoaPods, Maven, Dart and ~/.cache. Re-downloaded when needed."
        case .homebrew:
            "Outdated formula versions and downloads, removed with `brew cleanup`."
        case .docker:
            "Unused images, stopped containers, build cache and unused volumes, removed with `docker prune`. Docker must be running."
        case .iosBackups:
            "Local backups of your iPhone and iPad. They can't be recovered once deleted."
        case .deviceSoftwareUpdates:
            "iOS and iPadOS update files (.ipsw) that Finder downloaded. Downloaded again when needed."
        case .macOSInstallers:
            "\"Install macOS\" apps and leftovers from finished updates."
        case .timeMachineSnapshots:
            "Local snapshots that Time Machine keeps on this disk. Requires an administrator password."
        }
    }

    var systemImage: String {
        switch self {
        case .userCaches: "archivebox"
        case .appContainerCaches: "square.stack.3d.up"
        case .appSupportCaches: "globe"
        case .perUserSystemCaches: "gearshape.2"
        case .systemCaches: "internaldrive"
        case .userLogs: "doc.text"
        case .systemLogs: "doc.text.magnifyingglass"
        case .unifiedLogs: "list.bullet.rectangle"
        case .temporaryFiles: "clock.arrow.circlepath"
        case .mailDownloads: "envelope"
        case .xcodeDerivedData: "hammer"
        case .xcodePreviews: "eye"
        case .xcodeLeftovers: "wrench.and.screwdriver"
        case .xcodeArchives: "shippingbox"
        case .deviceSupport: "iphone"
        case .simulatorDevices: "ipad.and.iphone"
        case .simulatorRuntimes: "square.stack.3d.down.right"
        case .simulatorCaches: "apps.iphone"
        case .packageManagerCaches: "cube.box"
        case .homebrew: "mug"
        case .docker: "server.rack"
        case .iosBackups: "externaldrive"
        case .deviceSoftwareUpdates: "arrow.down.circle"
        case .macOSInstallers: "macwindow"
        case .timeMachineSnapshots: "camera.aperture"
        }
    }

    var risk: RiskLevel {
        switch self {
        case .userCaches, .userLogs, .systemLogs, .temporaryFiles, .xcodeDerivedData, .xcodePreviews,
             .xcodeLeftovers, .simulatorCaches, .homebrew, .deviceSoftwareUpdates:
            .safe
        case .appContainerCaches, .appSupportCaches, .perUserSystemCaches, .systemCaches, .unifiedLogs,
             .mailDownloads, .deviceSupport, .simulatorDevices, .simulatorRuntimes, .packageManagerCaches,
             .docker, .macOSInstallers:
            .review
        case .xcodeArchives, .iosBackups, .timeMachineSnapshots:
            .caution
        }
    }

    var group: CategoryGroup {
        switch self {
        case .userCaches, .appContainerCaches, .appSupportCaches, .perUserSystemCaches, .systemCaches,
             .userLogs, .systemLogs, .unifiedLogs, .temporaryFiles, .mailDownloads:
            .system
        case .xcodeDerivedData, .xcodePreviews, .xcodeLeftovers, .xcodeArchives, .deviceSupport,
             .simulatorDevices, .simulatorRuntimes, .simulatorCaches, .packageManagerCaches, .homebrew, .docker:
            .developer
        case .iosBackups, .deviceSoftwareUpdates, .macOSInstallers, .timeMachineSnapshots:
            .backups
        }
    }

    /// Items here are owned by root, so removal may need an admin password.
    var requiresAdministrator: Bool {
        switch self {
        case .systemCaches, .systemLogs, .unifiedLogs, .macOSInstallers, .timeMachineSnapshots: true
        default: false
        }
    }

    /// These locations are protected by TCC and can only be read reliably with Full Disk Access.
    var requiresFullDiskAccess: Bool {
        switch self {
        case .mailDownloads, .appContainerCaches: true
        default: false
        }
    }

    /// Only low-risk categories are pre-selected after a scan.
    var isSelectedByDefault: Bool { risk == .safe }

    /// macOS doesn't report the size of individual local snapshots.
    var hasUnknownItemSizes: Bool { self == .timeMachineSnapshots }
}

nonisolated enum CategoryGroup: String, CaseIterable, Identifiable, Sendable {
    case system
    case developer
    case backups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Caches & Logs"
        case .developer: "Developer"
        case .backups: "Backups & Installers"
        }
    }

    var categories: [CleanupCategory] {
        CleanupCategory.allCases.filter { $0.group == self }
    }
}
