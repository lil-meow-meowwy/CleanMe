import Foundation

/// Places that macOS counts as "System Data" but that can't be cleaned automatically
/// (or only partly). The Storage Breakdown measures them so users can see where space goes.
nonisolated enum InsightLocations {
    static var all: [InsightLocation] {
        let library = SystemDataLocations.library
        return [
            InsightLocation(
                title: "App Support Data",
                detail: "Data apps keep for themselves: databases, downloaded models, game assets. Remove it from inside the app or by uninstalling the app.",
                systemImage: "folder",
                url: library.appending(path: "Application Support", directoryHint: .isDirectory),
                relatedCategory: .appSupportCaches,
                breaksDownChildren: true
            ),
            InsightLocation(
                title: "App Containers",
                detail: "Data of sandboxed apps (Docker's disk image, Messages in iCloud, etc.). Only the caches inside are cleaned.",
                systemImage: "square.stack.3d.up",
                url: SystemDataLocations.containers,
                relatedCategory: .appContainerCaches,
                breaksDownChildren: true
            ),
            InsightLocation(
                title: "Group Containers",
                detail: "Data shared between apps from the same developer (Office, Notes, Telegram, etc.).",
                systemImage: "square.on.square",
                url: SystemDataLocations.groupContainers,
                relatedCategory: .appContainerCaches,
                breaksDownChildren: true
            ),
            InsightLocation(
                title: "Developer Data",
                detail: "Xcode build data, simulators, previews and device support.",
                systemImage: "hammer",
                url: SystemDataLocations.developer,
                relatedCategory: .xcodeDerivedData,
                breaksDownChildren: true
            ),
            InsightLocation(
                title: "Simulator Runtimes",
                detail: "Installed simulator runtime images.",
                systemImage: "square.stack.3d.down.right",
                url: SystemDataLocations.simulatorRuntimesDirectory,
                relatedCategory: .simulatorRuntimes,
                breaksDownChildren: false
            ),
            InsightLocation(
                title: "User Caches",
                detail: "Caches of non-sandboxed apps.",
                systemImage: "archivebox",
                url: library.appending(path: "Caches", directoryHint: .isDirectory),
                relatedCategory: .userCaches,
                breaksDownChildren: false
            ),
            InsightLocation(
                title: "Shared App Support",
                detail: "Data shared by all users, such as GarageBand sound libraries and printer drivers.",
                systemImage: "folder.badge.person.crop",
                url: URL(filePath: "/Library/Application Support", directoryHint: .isDirectory),
                relatedCategory: nil,
                breaksDownChildren: true
            ),
            InsightLocation(
                title: "Virtual Memory",
                detail: "Swap files and the sleep image. macOS manages these; a restart shrinks them.",
                systemImage: "memorychip",
                url: URL(filePath: "/private/var/vm", directoryHint: .isDirectory),
                relatedCategory: nil,
                breaksDownChildren: false
            ),
            InsightLocation(
                title: "System Temporary & Cache Folders",
                detail: "Per-user temporary files and caches for every account. A restart clears much of it.",
                systemImage: "clock.arrow.circlepath",
                url: URL(filePath: "/private/var/folders", directoryHint: .isDirectory),
                relatedCategory: .perUserSystemCaches,
                breaksDownChildren: false
            ),
            InsightLocation(
                title: "System Databases & Diagnostics",
                detail: "Diagnostics, unified logs and system databases. Logs can be erased; the rest is managed by macOS.",
                systemImage: "cylinder.split.1x2",
                url: URL(filePath: "/private/var/db", directoryHint: .isDirectory),
                relatedCategory: .unifiedLogs,
                breaksDownChildren: false
            ),
        ]
    }
}
