import Foundation

nonisolated protocol TimeMachineSnapshotProviding: Sendable {
    /// Names of local APFS snapshots, e.g. `com.apple.TimeMachine.2026-10-20-101500.local`.
    func listLocalSnapshots() async -> [String]
}

nonisolated struct TimeMachineService: TimeMachineSnapshotProviding {
    private let shell: any ShellCommandRunning

    init(shell: any ShellCommandRunning) {
        self.shell = shell
    }

    func listLocalSnapshots() async -> [String] {
        guard let output = try? await shell.run(
            AppConstants.Executables.tmutil,
            arguments: ["listlocalsnapshots", "/"]
        ) else { return [] }

        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(AppConstants.TimeMachine.snapshotPrefix) }
    }

    /// `com.apple.TimeMachine.2026-10-20-101500.local` → `2026-10-20-101500`
    /// (the format `tmutil deletelocalsnapshots` expects).
    static func dateComponent(fromSnapshotName name: String) -> String? {
        let prefix = AppConstants.TimeMachine.snapshotPrefix
        let suffix = AppConstants.TimeMachine.snapshotSuffix
        guard name.hasPrefix(prefix) else { return nil }

        var value = String(name.dropFirst(prefix.count))
        if value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }
        // Only digits and dashes, so the value is always safe to pass to a shell.
        guard !value.isEmpty, value.allSatisfy({ $0.isNumber || $0 == "-" }) else { return nil }
        return value
    }

    static func date(fromSnapshotName name: String) -> Date? {
        guard let component = dateComponent(fromSnapshotName: name) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = AppConstants.TimeMachine.snapshotDateFormat
        return formatter.date(from: component)
    }
}
