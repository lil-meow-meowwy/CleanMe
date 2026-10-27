import Foundation

nonisolated enum AppConstants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "CleanMe"

    nonisolated enum URLs {
        static let fullDiskAccessSettings = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )!
    }

    nonisolated enum DefaultsKeys {
        static let deletionMode = "settings.deletionMode"
        static let temporaryFileMinimumAgeDays = "settings.temporaryFileMinimumAgeDays"
        static let confirmBeforeCleaning = "settings.confirmBeforeCleaning"
        static let collapsedSidebarGroups = "sidebar.collapsedGroups"
    }

    nonisolated enum Defaults {
        static let deletionMode: DeletionMode = .trash
        static let temporaryFileMinimumAgeDays = 3
        static let temporaryFileMinimumAgeRange = 1...30
        static let confirmBeforeCleaning = true
    }

    nonisolated enum Scanning {
        /// Finder metadata that isn't worth listing.
        static let ignoredFileNames: Set<String> = [".DS_Store", ".localized"]

        /// Cache folders that hold state macOS services rely on. Deleting them
        /// can sign you out of iCloud services or break syncing, so they're never listed.
        static let protectedCacheNames: Set<String> = [
            "CloudKit",
            "FamilyCircle",
            "com.apple.akd",
            "com.apple.bird",
            "com.apple.containermanagerd",
            "com.apple.homed",
            "com.apple.HomeKit",
            "com.apple.iCloudHelper",
        ]

        static let secondsPerDay: TimeInterval = 86_400

        /// Entries of the per-user system cache folder (`/var/folders/…/C`) that are left alone:
        /// Spotlight's per-user data and the Launch Services database ("Open With" settings).
        static let protectedDarwinCachePrefixes: [String] = [
            "mds",
            "com.apple.LaunchServices",
            "com.apple.nsurlsessiond",
        ]

        /// Folder names that Chromium/Electron apps and browsers use for disposable caches
        /// inside `~/Library/Application Support`.
        static let appSupportCacheFolderNames: Set<String> = [
            "Cache",
            "Caches",
            "Code Cache",
            "GPUCache",
            "DawnCache",
            "DawnGraphiteCache",
            "DawnWebGPUCache",
            "GraphiteDawnCache",
            "GrShaderCache",
            "ShaderCache",
            "CacheStorage",
            "CachedData",
            "CachedExtensionVSIXs",
            "Crashpad",
            "component_crx_cache",
            "Media Cache",
        ]

        /// How deep to look for cache folders, e.g. `Google/Chrome/Default/Service Worker/CacheStorage` = 5.
        static let appSupportSearchDepth = 5

        /// Application Support folders that hold user data or system state; never searched.
        static let appSupportExcludedFolders: Set<String> = [
            "MobileSync",
            "AddressBook",
            "CallHistoryDB",
            "CallHistoryTransactions",
            "CloudDocs",
            "FileProvider",
            "Knowledge",
            "com.apple.TCC",
            "com.apple.sharedfilelist",
        ]
    }

    nonisolated enum FullDiskAccess {
        /// TCC-protected locations: if any of them is readable, the app has Full Disk Access.
        static let probePaths: [String] = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "~/Library/Safari",
            "~/Library/Mail",
        ]
    }

    nonisolated enum TimeMachine {
        static let snapshotPrefix = "com.apple.TimeMachine."
        static let snapshotSuffix = ".local"
        static let snapshotDateFormat = "yyyy-MM-dd-HHmmss"
    }

    nonisolated enum Executables {
        static let tmutil = "/usr/bin/tmutil"
        static let osascript = "/usr/bin/osascript"
        static let rm = "/bin/rm"
        static let xcrun = "/usr/bin/xcrun"
    }

    nonisolated enum Tools {
        static let dockerCandidates = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker",
            "~/.orbstack/bin/docker",
        ]
        static let homebrewCandidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]
        static let homebrewCleanupArguments = ["cleanup", "--prune=all", "-s"]
        static let homebrewDryRunArguments = ["cleanup", "--prune=all", "-n"]
        /// Extra PATH entries so tools started from a GUI app find their helpers.
        static let additionalPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        static let homebrewEnvironment = [
            "HOMEBREW_NO_AUTO_UPDATE": "1",
            "HOMEBREW_NO_ENV_HINTS": "1",
            "HOMEBREW_NO_INSTALL_CLEANUP": "1",
        ]
        static let log = "/usr/bin/log"
        static let xcodeBundleIdentifier = "com.apple.dt.Xcode"
        /// Where `xcode-select -s` stores the selected developer directory.
        static let xcodeSelectLink = "/var/db/xcode_select_link"
    }

    nonisolated enum Insights {
        static let largestItemsLimit = 20
        /// Hidden home folders smaller than this aren't listed.
        static let hiddenFolderMinimumSize: Int64 = 50 * 1024 * 1024
    }
}
