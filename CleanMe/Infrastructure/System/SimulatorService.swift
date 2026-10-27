import AppKit

nonisolated protocol SimulatorManaging: Sendable {
    /// `false` when no Xcode with `simctl` is installed (Command Line Tools alone don't have it).
    func isSimctlAvailable() -> Bool
    func listDevices() async -> [SimulatorDevice]
    func deleteDevices(udids: [String]) async throws
    func listRuntimes() async -> [SimulatorRuntime]
    func deleteRuntime(identifier: String) async throws
}

/// Talks to CoreSimulator through `simctl`. Deleting simulator folders by hand
/// would leave CoreSimulator's registry out of sync, so everything goes through simctl.
///
/// `xcrun simctl` fails when `xcode-select` points at the Command Line Tools, so the
/// service finds an installed Xcode itself and runs its `simctl` with `DEVELOPER_DIR` set.
nonisolated struct SimulatorService: SimulatorManaging {
    private nonisolated struct Simctl: Sendable {
        let executable: String
        let developerDirectory: String
    }

    private nonisolated enum SimctlError: LocalizedError {
        case notFound
        var errorDescription: String? {
            "simctl wasn't found. Install Xcode, or select it with: sudo xcode-select -s /Applications/Xcode.app"
        }
    }

    private let shell: any ShellCommandRunning

    init(shell: any ShellCommandRunning) {
        self.shell = shell
    }

    func isSimctlAvailable() -> Bool {
        Self.locateSimctl() != nil
    }

    private func runSimctl(_ arguments: [String]) async throws -> String {
        guard let simctl = Self.locateSimctl() else { throw SimctlError.notFound }
        return try await shell.run(
            simctl.executable,
            arguments: arguments,
            environment: ["DEVELOPER_DIR": simctl.developerDirectory]
        )
    }

    /// Order: `$DEVELOPER_DIR`, the `xcode-select` choice, then any installed Xcode
    /// (`/Applications/Xcode*.app`, `~/Applications/Xcode*.app`, Launch Services).
    private static func locateSimctl() -> Simctl? {
        let fileManager = FileManager.default
        var developerDirectories: [String] = []

        if let environment = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] {
            developerDirectories.append(environment)
        }
        if let selected = try? fileManager.destinationOfSymbolicLink(atPath: AppConstants.Tools.xcodeSelectLink) {
            developerDirectories.append(selected)
        }

        let applicationFolders = [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            SystemDataLocations.home.appending(path: "Applications", directoryHint: .isDirectory),
        ]
        for folder in applicationFolders {
            let xcodes = ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? [])
                .filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }
                .sorted { lhs, rhs in
                    // Prefer the plain "Xcode.app" over betas.
                    lhs == "Xcode.app" || (rhs != "Xcode.app" && lhs < rhs)
                }
            developerDirectories += xcodes.map { folder.appending(path: "\($0)/Contents/Developer").path }
        }
        developerDirectories += NSWorkspace.shared
            .urlsForApplications(withBundleIdentifier: AppConstants.Tools.xcodeBundleIdentifier)
            .map { $0.appending(path: "Contents/Developer").path }

        for directory in developerDirectories {
            let executable = (directory as NSString).appendingPathComponent("usr/bin/simctl")
            if fileManager.isExecutableFile(atPath: executable) {
                return Simctl(executable: executable, developerDirectory: directory)
            }
        }
        return nil
    }

    // MARK: - Devices

    func listDevices() async -> [SimulatorDevice] {
        await BackgroundWork.run { Self.readDevices() }
    }

    func deleteDevices(udids: [String]) async throws {
        let valid = udids.filter(Self.isValidIdentifier)
        guard !valid.isEmpty else { return }
        _ = try await runSimctl(["delete"] + valid)
    }

    /// Reads `~/Library/Developer/CoreSimulator/Devices/<UDID>/device.plist` directly,
    /// which is faster than `simctl list` and also gives us the folder to measure.
    private static func readDevices() -> [SimulatorDevice] {
        let fileManager = FileManager.default
        guard let directories = try? fileManager.contentsOfDirectory(
            at: SystemDataLocations.simulatorDevicesDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return directories.compactMap { directory -> SimulatorDevice? in
            guard !Task.isCancelled else { return nil }
            let plistURL = directory.appending(path: "device.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let udid = plist["UDID"] as? String,
                  isValidIdentifier(udid)
            else { return nil }

            let modified = try? directory.appending(path: "data")
                .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

            return SimulatorDevice(
                udid: udid,
                name: plist["name"] as? String ?? udid,
                runtime: (plist["runtime"] as? String).map(runtimeDisplayName) ?? "Unknown runtime",
                directory: directory,
                size: FileSizeCalculator.allocatedSize(of: directory),
                lastModified: modified
            )
        }
    }

    // MARK: - Runtimes

    func listRuntimes() async -> [SimulatorRuntime] {
        guard let output = try? await runSimctl(["runtime", "list", "-j"]),
            let data = output.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        return json.values.compactMap { value -> SimulatorRuntime? in
            guard let entry = value as? [String: Any],
                  let identifier = entry["identifier"] as? String,
                  Self.isValidIdentifier(identifier)
            else { return nil }

            let runtimeID = entry["runtimeIdentifier"] as? String
            let version = entry["version"] as? String
            let name: String
            if let runtimeID {
                name = Self.runtimeDisplayName(runtimeID)
            } else {
                name = [Self.platformName(entry["platformIdentifier"] as? String), version]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }

            let lastUsedString = entry["lastUsedAt"] as? String
            let lastUsed = lastUsedString.flatMap { dateFormatter.date(from: $0) ?? fallbackFormatter.date(from: $0) }

            return SimulatorRuntime(
                identifier: identifier,
                name: name.isEmpty ? identifier : name,
                build: entry["build"] as? String,
                size: (entry["sizeBytes"] as? NSNumber)?.int64Value,
                lastUsed: lastUsed,
                isDeletable: entry["deletable"] as? Bool ?? true
            )
        }
    }

    func deleteRuntime(identifier: String) async throws {
        guard Self.isValidIdentifier(identifier) else { return }
        _ = try await runSimctl(["runtime", "delete", identifier])
    }

    // MARK: - Helpers

    /// UDIDs/identifiers are UUIDs; reject anything else before passing it to a tool.
    static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isHexDigit || $0 == "-" }
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-18-2` → `iOS 18.2`
    static func runtimeDisplayName(_ identifier: String) -> String {
        guard let suffix = identifier.split(separator: ".").last else { return identifier }
        let parts = suffix.split(separator: "-").map(String.init)
        guard let platform = parts.first else { return identifier }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? platform : "\(platform) \(version)"
    }

    private static func platformName(_ platformIdentifier: String?) -> String? {
        guard let platformIdentifier else { return nil }
        if platformIdentifier.contains("iphone") { return "iOS" }
        if platformIdentifier.contains("watch") { return "watchOS" }
        if platformIdentifier.contains("appletv") { return "tvOS" }
        if platformIdentifier.contains("xr") { return "visionOS" }
        return nil
    }
}
