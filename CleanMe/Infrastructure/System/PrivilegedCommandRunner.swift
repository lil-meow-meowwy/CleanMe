import Foundation

nonisolated protocol PrivilegedCommandRunning: Sendable {
    /// Runs a shell command as root after the user authenticates in the standard macOS dialog.
    func runAsAdministrator(_ shellCommand: String) async throws
}

nonisolated enum PrivilegedCommandError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        "Administrator authorization was cancelled."
    }
}

/// Uses `osascript` + `do shell script … with administrator privileges`, which shows the
/// system authentication dialog without needing a privileged helper tool.
nonisolated struct AppleScriptPrivilegedRunner: PrivilegedCommandRunning {
    private static let userCancelledCode = "-128"
    private let shell: any ShellCommandRunning

    init(shell: any ShellCommandRunning) {
        self.shell = shell
    }

    func runAsAdministrator(_ shellCommand: String) async throws {
        let script = "do shell script \"\(ShellEscaping.appleScriptString(shellCommand))\" with administrator privileges"
        do {
            _ = try await shell.run(AppConstants.Executables.osascript, arguments: ["-e", script])
        } catch ShellError.nonZeroExit(_, let message) where message.contains(Self.userCancelledCode) {
            throw PrivilegedCommandError.cancelled
        }
    }
}
