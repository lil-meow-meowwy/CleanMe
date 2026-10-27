import Foundation

nonisolated protocol FileScanning: Sendable {
    func scan(_ category: CleanupCategory, options: ScanOptions) async -> CategoryScanResult
}

/// Finds removable items for each category and measures them.
nonisolated struct FileScanner: FileScanning {
    private let snapshotProvider: any TimeMachineSnapshotProviding
    private let simulators: any SimulatorManaging
    private let tools: any DeveloperToolsManaging

    init(
        snapshotProvider: any TimeMachineSnapshotProviding,
        simulators: any SimulatorManaging,
        tools: any DeveloperToolsManaging
    ) {
        self.snapshotProvider = snapshotProvider
        self.simulators = simulators
        self.tools = tools
    }

    func scan(_ category: CleanupCategory, options: ScanOptions) async -> CategoryScanResult {
        switch category {
        case .timeMachineSnapshots:
            return await scanSnapshots()
        case .simulatorDevices:
            return await scanSimulatorDevices()
        case .simulatorRuntimes:
            return await scanSimulatorRuntimes()
        case .appContainerCaches:
            return await BackgroundWork.run { Self.scanContainerCaches() }
        case .appSupportCaches:
            return await BackgroundWork.run { Self.scanAppSupportCaches() }
        case .unifiedLogs:
            return await BackgroundWork.run { Self.scanUnifiedLogs() }
        case .macOSInstallers:
            return await BackgroundWork.run { Self.scanMacOSInstallers() }
        case .homebrew:
            return await scanHomebrew()
        case .docker:
            return await scanDocker()
        default:
            return await BackgroundWork.run { Self.scanFileSystem(category, options: options) }
        }
    }

    // MARK: - Tool-managed categories

    private func scanSnapshots() async -> CategoryScanResult {
        let names = await snapshotProvider.listLocalSnapshots()
        let items = names.map { name in
            ScanItem(
                name: name,
                target: .snapshot(name),
                size: nil,
                modificationDate: TimeMachineService.date(fromSnapshotName: name)
            )
        }
        .sorted { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }

        return CategoryScanResult(category: .timeMachineSnapshots, items: items, inaccessiblePaths: [])
    }

    private func scanSimulatorDevices() async -> CategoryScanResult {
        let items = await simulators.listDevices()
            .map { device in
                ScanItem(
                    name: device.name,
                    detail: device.runtime,
                    target: .simulatorDevice(udid: device.udid, directory: device.directory),
                    size: device.size,
                    modificationDate: device.lastModified
                )
            }
            .sorted { ($0.size ?? 0) > ($1.size ?? 0) }

        return CategoryScanResult(
            category: .simulatorDevices,
            items: items,
            inaccessiblePaths: [],
            notice: simulators.isSimctlAvailable() ? nil : Self.simctlMissingNotice
        )
    }

    private func scanSimulatorRuntimes() async -> CategoryScanResult {
        let items = await simulators.listRuntimes()
            .filter(\.isDeletable)
            .map { runtime in
                ScanItem(
                    name: runtime.name,
                    detail: runtime.build,
                    target: .simulatorRuntime(identifier: runtime.identifier),
                    size: runtime.size,
                    modificationDate: runtime.lastUsed
                )
            }
            .sorted { ($0.size ?? 0) > ($1.size ?? 0) }

        return CategoryScanResult(
            category: .simulatorRuntimes,
            items: items,
            inaccessiblePaths: [],
            notice: simulators.isSimctlAvailable() ? nil : Self.simctlMissingNotice
        )
    }

    private static let simctlMissingNotice =
        "Xcode wasn't found, so simulators can't be removed. Install Xcode, or select it with "
        + "`sudo xcode-select -s /Applications/Xcode.app`."

    // MARK: - Docker & Homebrew

    private func scanDocker() async -> CategoryScanResult {
        switch await tools.dockerStatus() {
        case .notInstalled:
            return CategoryScanResult(category: .docker, items: [], inaccessiblePaths: [])
        case .notRunning:
            return CategoryScanResult(
                category: .docker,
                items: [],
                inaccessiblePaths: [],
                notice: "Docker is installed but not running. Start Docker Desktop (or OrbStack) and scan again."
            )
        case .running(let reclaimable):
            let items = DockerResource.allCases.compactMap { resource -> ScanItem? in
                guard let bytes = reclaimable[resource], bytes > 0 else { return nil }
                let command = CleanupCommand.docker(resource)
                return ScanItem(
                    name: resource.title,
                    detail: command.displayCommand,
                    target: .command(command),
                    size: bytes,
                    modificationDate: nil
                )
            }
            return CategoryScanResult(category: .docker, items: items, inaccessiblePaths: [])
        }
    }

    private func scanHomebrew() async -> CategoryScanResult {
        guard let bytes = await tools.homebrewReclaimableBytes(), bytes > 0 else {
            return CategoryScanResult(category: .homebrew, items: [], inaccessiblePaths: [])
        }
        let command = CleanupCommand.homebrewCleanup
        let item = ScanItem(
            name: "Old versions & downloads",
            detail: command.displayCommand,
            target: .command(command),
            size: bytes,
            modificationDate: nil
        )
        return CategoryScanResult(category: .homebrew, items: [item], inaccessiblePaths: [])
    }

    // MARK: - System tools

    private static func scanUnifiedLogs() -> CategoryScanResult {
        let directory = SystemDataLocations.unifiedLogsDirectory
        let measurement = FileSizeCalculator.measure(directory)
        guard measurement.bytes > 0 else {
            return CategoryScanResult(category: .unifiedLogs, items: [], inaccessiblePaths: [])
        }
        let command = CleanupCommand.eraseUnifiedLogs
        let item = ScanItem(
            name: "Unified log archive",
            detail: command.displayCommand,
            target: .command(command),
            size: measurement.bytes,
            modificationDate: nil
        )
        return CategoryScanResult(
            category: .unifiedLogs,
            items: [item],
            inaccessiblePaths: [],
            notice: measurement.isComplete ? nil : "Part of the log archive is only readable by the system, so the real size may be larger."
        )
    }

    /// `/Applications/Install macOS *.app` and `/macOS Install Data`.
    private static func scanMacOSInstallers() -> CategoryScanResult {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let apps = try? fileManager.contentsOfDirectory(
            at: SystemDataLocations.applications,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            candidates += apps.filter { PathSafetyValidator.isSafeToDelete($0, in: .macOSInstallers) }
        }
        let installData = SystemDataLocations.macOSInstallDataDirectory
        if fileManager.fileExists(atPath: installData.path) {
            candidates.append(installData)
        }

        var hasPartialSizes = false
        let items = candidates.compactMap { url -> ScanItem? in
            let measurement = FileSizeCalculator.measure(url)
            if !measurement.isComplete { hasPartialSizes = true }
            guard measurement.bytes > 0 else { return nil }
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return ScanItem(
                name: url.lastPathComponent,
                detail: url == installData ? "Leftover from a macOS update" : nil,
                target: .file(url),
                size: measurement.bytes,
                modificationDate: modified
            )
        }
        .sorted { ($0.size ?? 0) > ($1.size ?? 0) }

        return CategoryScanResult(
            category: .macOSInstallers,
            items: items,
            inaccessiblePaths: [],
            notice: hasPartialSizes ? "Some installer files are only readable by the system, so sizes may be larger." : nil
        )
    }

    // MARK: - Application Support caches

    /// Looks for known cache folder names (Cache, Code Cache, GPUCache…) a few levels deep in
    /// `~/Library/Application Support`. One item per cache folder; its contents are removed.
    private static func scanAppSupportCaches() -> CategoryScanResult {
        let fileManager = FileManager.default
        let base = SystemDataLocations.applicationSupport
        let cacheNames = AppConstants.Scanning.appSupportCacheFolderNames
        let maxDepth = AppConstants.Scanning.appSupportSearchDepth
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]

        var items: [ScanItem] = []
        // Breadth-first: (folder, depth of its children)
        var queue: [(URL, Int)] = [(base, 1)]

        while !queue.isEmpty {
            guard !Task.isCancelled else { break }
            let (folder, depth) = queue.removeFirst()
            guard let children = try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: keys,
                options: []
            ) else { continue }

            for child in children {
                guard let values = try? child.resourceValues(forKeys: Set(keys)),
                      values.isDirectory == true,
                      values.isSymbolicLink != true,
                      values.isPackage != true
                else { continue }

                let name = child.lastPathComponent
                if depth == 1 {
                    if AppConstants.Scanning.appSupportExcludedFolders.contains(name) || name == AppConstants.bundleIdentifier {
                        continue
                    }
                } else if cacheNames.contains(name) {
                    let measurement = FileSizeCalculator.measure(child)
                    if measurement.bytes > 0 {
                        let modified = try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                        items.append(
                            ScanItem(
                                name: String(child.path.dropFirst(base.path.count + 1)),
                                target: .directoryContents(child),
                                size: measurement.bytes,
                                modificationDate: modified
                            )
                        )
                    }
                    continue // Never look inside a cache folder.
                }

                if depth < maxDepth {
                    queue.append((child, depth + 1))
                }
            }
        }

        items.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        return CategoryScanResult(category: .appSupportCaches, items: items, inaccessiblePaths: [])
    }

    // MARK: - App containers

    /// One item per app: the contents of its container's `Caches` folder.
    private static func scanContainerCaches() -> CategoryScanResult {
        var items: [ScanItem] = []
        var hasUnreadable = false

        for location in SystemDataLocations.containerCacheLocations() {
            guard !Task.isCancelled else { break }
            let identifier = location.identifier
            if identifier == AppConstants.bundleIdentifier
                || AppConstants.Scanning.protectedCacheNames.contains(identifier) {
                continue
            }

            let measurement = FileSizeCalculator.measure(location.directory)
            if !measurement.isComplete { hasUnreadable = true }
            guard measurement.bytes > 0 else { continue }

            let modified = try? location.directory
                .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            items.append(
                ScanItem(
                    name: identifier,
                    detail: location.isGroupContainer ? "Group container" : nil,
                    target: .directoryContents(location.directory),
                    size: measurement.bytes,
                    modificationDate: modified
                )
            )
        }

        items.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        let inaccessible = hasUnreadable ? [SystemDataLocations.containers.path] : []
        return CategoryScanResult(category: .appContainerCaches, items: items, inaccessiblePaths: inaccessible)
    }

    // MARK: - Plain folders

    private static func scanFileSystem(_ category: CleanupCategory, options: ScanOptions) -> CategoryScanResult {
        let fileManager = FileManager.default
        var items: [ScanItem] = []
        var inaccessible: [String] = []

        for root in SystemDataLocations.roots(for: category) {
            guard !Task.isCancelled else { break }
            guard fileManager.fileExists(atPath: root.path) else { continue }

            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey],
                    options: []
                )
            } catch {
                inaccessible.append(root.path)
                continue
            }

            let rootLabel = SystemDataLocations.roots(for: category).count > 1
                ? SystemDataLocations.abbreviated(root)
                : nil

            for child in children {
                guard !Task.isCancelled else { break }
                guard !shouldSkip(child, category: category, options: options) else { continue }

                let size = FileSizeCalculator.allocatedSize(of: child)
                guard size > 0 else { continue }

                let modified = try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                items.append(
                    ScanItem(
                        name: child.lastPathComponent,
                        detail: rootLabel,
                        target: .file(child),
                        size: size,
                        modificationDate: modified
                    )
                )
            }
        }

        items.sort { ($0.size ?? 0) > ($1.size ?? 0) }
        return CategoryScanResult(category: category, items: items, inaccessiblePaths: inaccessible)
    }

    private static func shouldSkip(_ url: URL, category: CleanupCategory, options: ScanOptions) -> Bool {
        let name = url.lastPathComponent
        if AppConstants.Scanning.ignoredFileNames.contains(name) { return true }

        switch category {
        case .userCaches, .systemCaches:
            return AppConstants.Scanning.protectedCacheNames.contains(name)
                || name == AppConstants.bundleIdentifier
        case .perUserSystemCaches:
            return AppConstants.Scanning.protectedDarwinCachePrefixes.contains { name.hasPrefix($0) }
                || name == AppConstants.bundleIdentifier
        case .temporaryFiles:
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return Date().timeIntervalSince(modified) < options.temporaryFileMinimumAge
        default:
            return false
        }
    }
}
