import Foundation

nonisolated protocol FileCleaning: Sendable {
    func clean(_ itemsByCategory: [CleanupCategory: [ScanItem]], mode: DeletionMode) async -> CleanupReport
}

/// Removes scan items:
/// 1. regular files/folders with `FileManager` (Trash or permanent),
/// 2. simulators through `simctl`, Docker and Homebrew through their CLIs,
/// 3. system-owned items and Time Machine snapshots through a single admin prompt.
nonisolated struct FileCleaner: FileCleaning {
    private let privilegedRunner: any PrivilegedCommandRunning
    private let snapshotProvider: any TimeMachineSnapshotProviding
    private let simulators: any SimulatorManaging
    private let tools: any DeveloperToolsManaging

    init(
        privilegedRunner: any PrivilegedCommandRunning,
        snapshotProvider: any TimeMachineSnapshotProviding,
        simulators: any SimulatorManaging,
        tools: any DeveloperToolsManaging
    ) {
        self.privilegedRunner = privilegedRunner
        self.snapshotProvider = snapshotProvider
        self.simulators = simulators
        self.tools = tools
    }

    func clean(_ itemsByCategory: [CleanupCategory: [ScanItem]], mode: DeletionMode) async -> CleanupReport {
        var outcome = await BackgroundWork.run {
            Self.removeWithFileManager(itemsByCategory, mode: mode)
        }

        if !outcome.pendingSimulatorDevices.isEmpty || !outcome.pendingSimulatorRuntimes.isEmpty {
            await removeSimulators(&outcome)
        }
        if !outcome.pendingCommands.isEmpty {
            await runToolCommands(&outcome)
        }
        if !outcome.pendingPrivileged.isEmpty {
            await removeWithPrivileges(&outcome)
        }

        return CleanupReport(
            freedBytes: outcome.freedBytes,
            removedItemIDs: outcome.removedIDs,
            failures: outcome.failures,
            mode: mode,
            date: .now
        )
    }

    // MARK: - FileManager removal

    private static func removeWithFileManager(
        _ itemsByCategory: [CleanupCategory: [ScanItem]],
        mode: DeletionMode
    ) -> CleanupOutcome {
        var outcome = CleanupOutcome()

        for (category, items) in itemsByCategory {
            for item in items {
                switch item.target {
                case .file(let url):
                    removeFile(item, at: url, category: category, mode: mode, outcome: &outcome)
                case .directoryContents(let directory):
                    emptyDirectory(item, at: directory, category: category, mode: mode, outcome: &outcome)
                case .snapshot:
                    outcome.pendingPrivileged.append(item)
                case .simulatorDevice:
                    outcome.pendingSimulatorDevices.append(item)
                case .simulatorRuntime:
                    outcome.pendingSimulatorRuntimes.append(item)
                case .command(.eraseUnifiedLogs):
                    outcome.pendingPrivileged.append(item)
                case .command:
                    outcome.pendingCommands.append(item)
                }
            }
        }
        return outcome
    }

    private static func removeFile(
        _ item: ScanItem,
        at url: URL,
        category: CleanupCategory,
        mode: DeletionMode,
        outcome: inout CleanupOutcome
    ) {
        guard PathSafetyValidator.isSafeToDelete(url, in: category) else {
            outcome.failures.append(.init(name: item.name, reason: "Skipped: outside of the allowed cleanup locations."))
            return
        }
        // `attributesOfItem` doesn't follow symlinks, so broken links are still found.
        guard exists(url) else {
            outcome.removedIDs.insert(item.id) // Already gone.
            return
        }

        do {
            try remove(url, mode: mode)
            outcome.removedIDs.insert(item.id)
            outcome.freedBytes += item.size ?? 0
        } catch {
            if category.requiresAdministrator && isPermissionError(error) {
                outcome.pendingPrivileged.append(item)
                return
            }
            // A folder may have been partially removed before the error.
            let remaining = FileSizeCalculator.allocatedSize(of: url)
            outcome.freedBytes += max((item.size ?? 0) - remaining, 0)
            outcome.failures.append(.init(name: item.name, reason: error.localizedDescription))
        }
    }

    private static func emptyDirectory(
        _ item: ScanItem,
        at directory: URL,
        category: CleanupCategory,
        mode: DeletionMode,
        outcome: inout CleanupOutcome
    ) {
        guard PathSafetyValidator.isSafeToEmpty(directory, in: category) else {
            outcome.failures.append(.init(name: item.name, reason: "Skipped: not an app cache folder."))
            return
        }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            outcome.failures.append(.init(name: item.name, reason: "The folder couldn't be read."))
            return
        }

        var firstError: Error?
        for child in children {
            do {
                try remove(child, mode: mode)
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError {
            let remaining = FileSizeCalculator.allocatedSize(of: directory)
            outcome.freedBytes += max((item.size ?? 0) - remaining, 0)
            outcome.failures.append(.init(name: item.name, reason: firstError.localizedDescription))
        } else {
            outcome.removedIDs.insert(item.id)
            outcome.freedBytes += item.size ?? 0
        }
    }

    private static func remove(_ url: URL, mode: DeletionMode) throws {
        switch mode {
        case .trash: try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        case .permanent: try FileManager.default.removeItem(at: url)
        }
    }

    private static func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let permissionCodes = [Int(EACCES), Int(EPERM)]
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(nsError.code) {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain, permissionCodes.contains(nsError.code) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           permissionCodes.contains(underlying.code) {
            return true
        }
        return false
    }

    // MARK: - Simulators

    private func removeSimulators(_ outcome: inout CleanupOutcome) async {
        let devices = outcome.pendingSimulatorDevices
        let runtimes = outcome.pendingSimulatorRuntimes
        outcome.pendingSimulatorDevices = []
        outcome.pendingSimulatorRuntimes = []

        if !devices.isEmpty {
            var deviceDirectories: [(item: ScanItem, directory: URL)] = []
            var udids: [String] = []
            for item in devices {
                if case .simulatorDevice(let udid, let directory) = item.target {
                    udids.append(udid)
                    deviceDirectories.append((item, directory))
                }
            }

            var runError: Error?
            do {
                try await simulators.deleteDevices(udids: udids)
            } catch {
                runError = error
            }

            // Verify per device: simctl removes the device folder when it succeeds.
            for (item, directory) in deviceDirectories {
                if Self.exists(directory) {
                    let reason = runError?.localizedDescription ?? "The simulator couldn't be deleted."
                    outcome.failures.append(.init(name: item.name, reason: reason))
                } else {
                    outcome.removedIDs.insert(item.id)
                    outcome.freedBytes += item.size ?? 0
                }
            }
        }

        for item in runtimes {
            guard case .simulatorRuntime(let identifier) = item.target else { continue }
            do {
                try await simulators.deleteRuntime(identifier: identifier)
                outcome.removedIDs.insert(item.id)
                outcome.freedBytes += item.size ?? 0
            } catch {
                outcome.failures.append(.init(name: item.name, reason: error.localizedDescription))
            }
        }
    }

    // MARK: - Docker & Homebrew

    private func runToolCommands(_ outcome: inout CleanupOutcome) async {
        let items = outcome.pendingCommands
        outcome.pendingCommands = []

        for item in items {
            guard case .command(let command) = item.target else { continue }
            do {
                switch command {
                case .docker(let resource):
                    try await tools.pruneDocker(resource)
                case .homebrewCleanup:
                    try await tools.runHomebrewCleanup()
                case .eraseUnifiedLogs:
                    continue // Handled by the privileged step.
                }
                outcome.removedIDs.insert(item.id)
                outcome.freedBytes += item.size ?? 0
            } catch {
                outcome.failures.append(.init(name: item.name, reason: error.localizedDescription))
            }
        }
    }

    // MARK: - Privileged removal

    private func removeWithPrivileges(_ outcome: inout CleanupOutcome) async {
        let pending = outcome.pendingPrivileged
        outcome.pendingPrivileged = []

        var commands: [String] = []
        var files: [(item: ScanItem, url: URL)] = []
        var snapshots: [ScanItem] = []
        var privilegedCommands: [ScanItem] = []

        for item in pending {
            switch item.target {
            case .file(let url):
                commands.append("\(AppConstants.Executables.rm) -rf -- \(ShellEscaping.singleQuoted(url.path))")
                files.append((item, url))
            case .snapshot(let name):
                guard let date = TimeMachineService.dateComponent(fromSnapshotName: name) else {
                    outcome.failures.append(.init(name: item.name, reason: "Unrecognized snapshot name."))
                    continue
                }
                commands.append("\(AppConstants.Executables.tmutil) deletelocalsnapshots \(ShellEscaping.singleQuoted(date))")
                snapshots.append(item)
            case .command(.eraseUnifiedLogs):
                commands.append("\(AppConstants.Tools.log) erase --all")
                privilegedCommands.append(item)
            case .directoryContents, .simulatorDevice, .simulatorRuntime, .command:
                outcome.failures.append(.init(name: item.name, reason: "This item can't be removed with administrator rights."))
            }
        }

        guard !commands.isEmpty else { return }

        var runError: Error?
        do {
            // `;` so one failing command doesn't stop the rest. Results are verified below.
            try await privilegedRunner.runAsAdministrator(commands.joined(separator: " ; "))
        } catch {
            runError = error
        }

        let failureReason = runError?.localizedDescription ?? "The item couldn't be removed."

        for (item, url) in files {
            if Self.exists(url) {
                outcome.failures.append(.init(name: item.name, reason: failureReason))
            } else {
                outcome.removedIDs.insert(item.id)
                outcome.freedBytes += item.size ?? 0
            }
        }

        for item in privilegedCommands {
            if runError == nil {
                outcome.removedIDs.insert(item.id)
                outcome.freedBytes += item.size ?? 0
            } else {
                outcome.failures.append(.init(name: item.name, reason: failureReason))
            }
        }

        if !snapshots.isEmpty {
            let remaining = Set(await snapshotProvider.listLocalSnapshots())
            for item in snapshots {
                if case .snapshot(let name) = item.target, !remaining.contains(name) {
                    outcome.removedIDs.insert(item.id)
                } else {
                    outcome.failures.append(.init(name: item.name, reason: failureReason))
                }
            }
        }
    }
}

nonisolated private struct CleanupOutcome: Sendable {
    var freedBytes: Int64 = 0
    var removedIDs: Set<ScanItem.ID> = []
    var failures: [CleanupReport.Failure] = []
    var pendingPrivileged: [ScanItem] = []
    var pendingSimulatorDevices: [ScanItem] = []
    var pendingSimulatorRuntimes: [ScanItem] = []
    var pendingCommands: [ScanItem] = []
}
