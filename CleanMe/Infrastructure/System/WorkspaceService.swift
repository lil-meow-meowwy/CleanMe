import AppKit

/// Thin wrapper over `NSWorkspace` so view models stay free of AppKit.
protocol WorkspaceServicing {
    func reveal(_ urls: [URL])
    func open(_ url: URL)
    func openFullDiskAccessSettings()
    func openTrash()
}

final class WorkspaceService: WorkspaceServicing {
    func reveal(_ urls: [URL]) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(existing)
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(AppConstants.URLs.fullDiskAccessSettings)
    }

    func openTrash() {
        guard let trash = try? FileManager.default.url(
            for: .trashDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        NSWorkspace.shared.open(trash)
    }
}
