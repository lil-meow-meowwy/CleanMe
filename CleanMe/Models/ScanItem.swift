import Foundation

/// A single removable entry found during a scan.
nonisolated struct ScanItem: Identifiable, Hashable, Sendable {
    nonisolated enum Target: Hashable, Sendable {
        /// Remove the file or folder itself.
        case file(URL)
        /// Empty the folder but keep it (used for caches inside app containers).
        case directoryContents(URL)
        /// A local Time Machine APFS snapshot, removed with `tmutil`.
        case snapshot(String)
        /// A simulator device, removed with `xcrun simctl delete`.
        case simulatorDevice(udid: String, directory: URL)
        /// A simulator runtime disk image, removed with `xcrun simctl runtime delete`.
        case simulatorRuntime(identifier: String)
        /// A cleanup performed by a command-line tool (Docker, Homebrew, `log`).
        case command(CleanupCommand)
    }

    let id: String
    let name: String
    /// Secondary text, e.g. the runtime of a simulator.
    let detail: String?
    let target: Target
    /// Allocated size on disk in bytes, `nil` when the system can't report it.
    let size: Int64?
    let modificationDate: Date?

    init(name: String, detail: String? = nil, target: Target, size: Int64?, modificationDate: Date?) {
        switch target {
        case .file(let url): self.id = url.path
        case .directoryContents(let url): self.id = "contents:\(url.path)"
        case .snapshot(let name): self.id = "snapshot:\(name)"
        case .simulatorDevice(let udid, _): self.id = "simdevice:\(udid)"
        case .simulatorRuntime(let identifier): self.id = "simruntime:\(identifier)"
        case .command(let command): self.id = "command:\(command.id)"
        }
        self.name = name
        self.detail = detail
        self.target = target
        self.size = size
        self.modificationDate = modificationDate
    }

    /// A location that can be shown in Finder, if there is one.
    var url: URL? {
        switch target {
        case .file(let url), .directoryContents(let url): url
        case .simulatorDevice(_, let directory): directory
        case .snapshot, .simulatorRuntime, .command: nil
        }
    }

    var path: String {
        switch target {
        case .file(let url), .directoryContents(let url): url.path
        case .snapshot(let name): name
        case .simulatorDevice(_, let directory): directory.path
        case .simulatorRuntime(let identifier): identifier
        case .command(let command): command.displayCommand
        }
    }
}
