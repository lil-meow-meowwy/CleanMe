import Foundation

/// Where each category lives on disk. For file-based categories only the *children*
/// of these folders are ever removed; the folders themselves are never deleted.
nonisolated enum SystemDataLocations {
    nonisolated struct ContainerCacheLocation: Sendable {
        let identifier: String
        let directory: URL
        let isGroupContainer: Bool
    }

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var library: URL { home.appending(path: "Library", directoryHint: .isDirectory) }
    static var developer: URL { library.appending(path: "Developer", directoryHint: .isDirectory) }
    static var xcode: URL { developer.appending(path: "Xcode", directoryHint: .isDirectory) }

    static var containers: URL { library.appending(path: "Containers", directoryHint: .isDirectory) }
    static var groupContainers: URL { library.appending(path: "Group Containers", directoryHint: .isDirectory) }

    static var simulatorDevicesDirectory: URL {
        developer.appending(path: "CoreSimulator/Devices", directoryHint: .isDirectory)
    }

    static let simulatorRuntimesDirectory = URL(filePath: "/Library/Developer/CoreSimulator", directoryHint: .isDirectory)

    static var applicationSupport: URL {
        library.appending(path: "Application Support", directoryHint: .isDirectory)
    }

    static let applications = URL(filePath: "/Applications", directoryHint: .isDirectory)
    static let unifiedLogsDirectory = URL(filePath: "/private/var/db/diagnostics", directoryHint: .isDirectory)

    /// Leftovers of a finished macOS update; removed as a whole.
    static let macOSInstallDataDirectory = URL(filePath: "/macOS Install Data", directoryHint: .isDirectory)

    /// The per-user cache folder (`/var/folders/xx/yyyy/C/`), sibling of `$TMPDIR`.
    static var darwinUserCacheDirectory: URL? {
        let length = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
        guard length > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: length)
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, length) > 0 else { return nil }
        return URL(filePath: String(cString: buffer), directoryHint: .isDirectory)
    }

    /// Folders whose children are scan items. Empty for categories managed by tools
    /// (`tmutil`, `simctl`) or by containers (see `containerCacheLocations()`).
    static func roots(for category: CleanupCategory) -> [URL] {
        switch category {
        case .userCaches:
            return [library.appending(path: "Caches", directoryHint: .isDirectory)]
        case .systemCaches:
            return [URL(filePath: "/Library/Caches", directoryHint: .isDirectory)]
        case .userLogs:
            return [library.appending(path: "Logs", directoryHint: .isDirectory)]
        case .systemLogs:
            return [
                URL(filePath: "/Library/Logs", directoryHint: .isDirectory),
                URL(filePath: "/private/var/log", directoryHint: .isDirectory),
            ]
        case .temporaryFiles:
            return [FileManager.default.temporaryDirectory]
        case .perUserSystemCaches:
            return darwinUserCacheDirectory.map { [$0] } ?? []
        case .mailDownloads:
            return [
                library.appending(
                    path: "Containers/com.apple.mail/Data/Library/Mail Downloads",
                    directoryHint: .isDirectory
                )
            ]
        case .xcodeDerivedData:
            return [xcode.appending(path: "DerivedData", directoryHint: .isDirectory)]
        case .xcodePreviews:
            return [
                xcode.appending(path: "UserData/Previews", directoryHint: .isDirectory),
                developer.appending(path: "XCPGDevices", directoryHint: .isDirectory),
            ]
        case .xcodeLeftovers:
            return [
                "DocumentationCache",
                "iOS Device Logs",
                "watchOS Device Logs",
                "Products",
                "UserData/IB Support",
            ].map { xcode.appending(path: $0, directoryHint: .isDirectory) }
        case .xcodeArchives:
            return [xcode.appending(path: "Archives", directoryHint: .isDirectory)]
        case .deviceSupport:
            return ["iOS", "watchOS", "tvOS", "visionOS", "macOS"].map {
                xcode.appending(path: "\($0) DeviceSupport", directoryHint: .isDirectory)
            }
        case .simulatorCaches:
            return [developer.appending(path: "CoreSimulator/Caches", directoryHint: .isDirectory)]
        case .packageManagerCaches:
            return [
                ".npm/_cacache",
                ".gradle/caches",
                ".cocoapods/repos",
                ".m2/repository",
                ".pub-cache",
                ".cache",
            ].map { home.appending(path: $0, directoryHint: .isDirectory) }
        case .iosBackups:
            return [library.appending(path: "Application Support/MobileSync/Backup", directoryHint: .isDirectory)]
        case .deviceSoftwareUpdates:
            return ["iPhone", "iPad", "iPod"].map {
                library.appending(path: "iTunes/\($0) Software Updates", directoryHint: .isDirectory)
            }
        case .macOSInstallers:
            // Only "Install macOS …" apps are taken from here (see PathSafetyValidator).
            return [applications]
        case .appContainerCaches, .appSupportCaches, .unifiedLogs, .simulatorDevices, .simulatorRuntimes,
             .homebrew, .docker, .timeMachineSnapshots:
            return []
        }
    }

    /// `~/Library/Containers/<id>/Data/Library/Caches` and `~/Library/Group Containers/<id>/Library/Caches`.
    static func containerCacheLocations() -> [ContainerCacheLocation] {
        let fileManager = FileManager.default
        var locations: [ContainerCacheLocation] = []

        if let identifiers = try? fileManager.contentsOfDirectory(atPath: containers.path) {
            locations += identifiers.map {
                ContainerCacheLocation(
                    identifier: $0,
                    directory: containers.appending(path: "\($0)/Data/Library/Caches", directoryHint: .isDirectory),
                    isGroupContainer: false
                )
            }
        }
        if let identifiers = try? fileManager.contentsOfDirectory(atPath: groupContainers.path) {
            locations += identifiers.map {
                ContainerCacheLocation(
                    identifier: $0,
                    directory: groupContainers.appending(path: "\($0)/Library/Caches", directoryHint: .isDirectory),
                    isGroupContainer: true
                )
            }
        }
        return locations.filter { fileManager.fileExists(atPath: $0.directory.path) }
    }

    /// Paths shown in the category header.
    static func displayPaths(for category: CleanupCategory) -> [String] {
        switch category {
        case .appContainerCaches:
            return ["~/Library/Containers/*/Data/Library/Caches", "~/Library/Group Containers/*/Library/Caches"]
        case .appSupportCaches:
            return ["~/Library/Application Support/**/{Cache, Code Cache, GPUCache, CacheStorage, …}"]
        case .unifiedLogs:
            return [unifiedLogsDirectory.path + " (via log erase)"]
        case .macOSInstallers:
            return ["/Applications/Install macOS *.app", macOSInstallDataDirectory.path]
        case .homebrew:
            return ["brew cleanup --prune=all"]
        case .docker:
            return ["docker system df / docker prune"]
        case .simulatorDevices:
            return [abbreviated(simulatorDevicesDirectory) + " (via simctl)"]
        case .simulatorRuntimes:
            return [abbreviated(simulatorRuntimesDirectory) + " (via simctl)"]
        case .timeMachineSnapshots:
            return ["Managed by Time Machine (tmutil)"]
        default:
            return roots(for: category).map(abbreviated)
        }
    }

    /// The folder opened by "Open in Finder" for a category.
    static func revealDirectory(for category: CleanupCategory) -> URL? {
        let candidates: [URL] = switch category {
        case .appContainerCaches: [containers]
        case .appSupportCaches: [applicationSupport]
        case .unifiedLogs: [unifiedLogsDirectory]
        case .homebrew, .docker: []
        case .simulatorDevices: [simulatorDevicesDirectory]
        case .simulatorRuntimes: [simulatorRuntimesDirectory]
        default: roots(for: category)
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func abbreviated(_ url: URL) -> String {
        let homePath = home.path
        let path = url.path
        return path.hasPrefix(homePath) ? "~" + path.dropFirst(homePath.count) : path
    }
}
