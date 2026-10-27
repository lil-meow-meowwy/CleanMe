import Foundation

/// Last line of defence before anything is deleted.
nonisolated enum PathSafetyValidator {
    /// An item may only be removed if it lives *inside* one of its category's root folders.
    static func isSafeToDelete(_ url: URL, in category: CleanupCategory) -> Bool {
        let name = url.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", name != "/" else { return false }

        if category == .macOSInstallers {
            return isMacOSInstaller(url)
        }

        // Resolve only the parent so a symlinked item is judged by where it sits,
        // not by where it points. Removing a symlink never touches its target.
        let parentPath = normalizedPath(of: url.deletingLastPathComponent())

        return SystemDataLocations.roots(for: category).contains { root in
            let rootPath = normalizedPath(of: root)
            return parentPath == rootPath || parentPath.hasPrefix(rootPath + "/")
        }
    }

    /// A folder may only be emptied if it is exactly an app container's `Caches` folder:
    /// `~/Library/Containers/<id>/Data/Library/Caches` or
    /// `~/Library/Group Containers/<id>/Library/Caches`.
    /// Because symlinks are resolved first, a `Caches` link pointing elsewhere is rejected.
    static func isSafeToEmpty(_ directory: URL, in category: CleanupCategory) -> Bool {
        let path = normalizedPath(of: directory)

        switch category {
        case .appContainerCaches:
            return matches(path, base: SystemDataLocations.containers, suffix: ["Data", "Library", "Caches"])
                || matches(path, base: SystemDataLocations.groupContainers, suffix: ["Library", "Caches"])
        case .appSupportCaches:
            return isAppSupportCacheFolder(path)
        default:
            return false
        }
    }

    /// `~/Library/Application Support/<1…depth components>` whose last component is a known cache name.
    private static func isAppSupportCacheFolder(_ path: String) -> Bool {
        let basePath = normalizedPath(of: SystemDataLocations.applicationSupport)
        guard path.hasPrefix(basePath + "/") else { return false }

        let components = path.dropFirst(basePath.count + 1).split(separator: "/").map(String.init)
        guard (2...AppConstants.Scanning.appSupportSearchDepth).contains(components.count),
              !components.contains(where: { $0 == "." || $0 == ".." }),
              let first = components.first,
              !AppConstants.Scanning.appSupportExcludedFolders.contains(first),
              let last = components.last
        else { return false }
        return AppConstants.Scanning.appSupportCacheFolderNames.contains(last)
    }

    /// Only `/Applications/Install macOS *.app` and `/macOS Install Data`.
    private static func isMacOSInstaller(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        let parentPath = normalizedPath(of: url.deletingLastPathComponent())
        if parentPath == normalizedPath(of: SystemDataLocations.applications) {
            return name.hasPrefix("Install macOS") && name.hasSuffix(".app")
        }
        return normalizedPath(of: url) == normalizedPath(of: SystemDataLocations.macOSInstallDataDirectory)
    }

    private static func matches(_ path: String, base: URL, suffix: [String]) -> Bool {
        let basePath = normalizedPath(of: base)
        guard path.hasPrefix(basePath + "/") else { return false }

        let components = path.dropFirst(basePath.count + 1).split(separator: "/").map(String.init)
        guard components.count == suffix.count + 1,
              let identifier = components.first,
              !identifier.isEmpty, identifier != ".", identifier != ".."
        else { return false }
        return Array(components.dropFirst()) == suffix
    }

    private static func normalizedPath(of url: URL) -> String {
        var path = url.resolvingSymlinksInPath().standardizedFileURL.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
