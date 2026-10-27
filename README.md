# CleanMe

A macOS SwiftUI app that scans and cleans the files behind **System Data** in
System Settings › General › Storage.

## Getting started

### Requirements

- macOS 27 or later
- Xcode 27 or later

### Build and run

```sh
git clone <repo-url>
cd CleanMe
open CleanMe.xcodeproj
```

Select the **CleanMe** scheme and press **⌘R**. There are no third-party dependencies.

From the command line:

```sh
xcodebuild -project CleanMe.xcodeproj -scheme CleanMe -configuration Release build
```

To run it on your own Mac, set your team under *Signing & Capabilities*; the bundle
identifier is a placeholder (`devplaceholder.…`).

## Usage

1. Press **⌘R** (or *File › Scan System Data*) to scan.
2. Review the categories; open one to see and select individual items.
3. Press **⌘↩** to clean the selection. A report sheet shows what was removed and how much space was freed.

### Settings (⌘,)

- **Removed items:** move to Trash (default) or delete permanently
- **Ask for confirmation before cleaning**
- **Temporary files:** skip files newer than N days
- **Permissions:** Full Disk Access status, with a link to System Settings

## What it cleans

| Group | Category | How it's cleaned | Risk |
|---|---|---|---|
| Caches & Logs | User Caches | `~/Library/Caches/*` | Safe |
| | App Container Caches | contents of `~/Library/Containers/*/Data/Library/Caches`, `~/Library/Group Containers/*/Library/Caches` | Review |
| | Browser & App Caches | contents of `Cache`, `Code Cache`, `GPUCache`, `CacheStorage`… found ≤5 levels deep in `~/Library/Application Support` (Chrome, Slack, Teams, VS Code…) | Review |
| | System Cache Folder | `/var/folders/…/C/*` (`DARWIN_USER_CACHE_DIR`), except Spotlight & Launch Services | Review |
| | System Caches | `/Library/Caches/*` (admin) | Review |
| | User Logs | `~/Library/Logs/*` | Safe |
| | System Logs | `/Library/Logs/*`, `/private/var/log/*` (admin) | Safe |
| | Unified Logs | `log erase --all` (admin) | Review |
| | Temporary Files | `$TMPDIR/*` older than N days | Safe |
| | Mail Downloads | `~/Library/Containers/com.apple.mail/…/Mail Downloads/*` (Full Disk Access) | Review |
| Developer | Xcode Derived Data | `~/Library/Developer/Xcode/DerivedData/*` | Safe |
| | Xcode Previews | `Xcode/UserData/Previews/*`, `~/Library/Developer/XCPGDevices/*` | Safe |
| | Xcode Leftovers | `Xcode/DocumentationCache`, `iOS/watchOS Device Logs`, `Products`, `UserData/IB Support` | Safe |
| | Xcode Archives | `~/Library/Developer/Xcode/Archives/*` | Caution |
| | Device Support | `~/Library/Developer/Xcode/{iOS,watchOS,tvOS,visionOS,macOS} DeviceSupport/*` | Review |
| | Simulator Devices | `xcrun simctl delete <UDID>` | Review |
| | Simulator Runtimes | `xcrun simctl runtime delete <id>` | Review |
| | Simulator Caches | `~/Library/Developer/CoreSimulator/Caches/*` | Safe |
| | Package Caches | `~/.npm/_cacache`, `~/.gradle/caches`, `~/.cocoapods/repos`, `~/.m2/repository`, `~/.pub-cache`, `~/.cache` | Review |
| | Homebrew | `brew cleanup --prune=all -s` | Safe |
| | Docker | `docker image/container/volume/builder prune` (Docker must be running) | Review |
| Backups & Installers | iPhone & iPad Backups | `~/Library/Application Support/MobileSync/Backup/*` | Caution |
| | Device Software Updates | `~/Library/iTunes/{iPhone,iPad,iPod} Software Updates/*.ipsw` | Safe |
| | macOS Installers | `/Applications/Install macOS *.app`, `/macOS Install Data` (admin) | Review |
| | Time Machine Snapshots | `tmutil deletelocalsnapshots` (admin) | Caution |

Only "Safe" categories are pre-selected after a scan.

## Storage Breakdown

System Settings counts much more as "System Data" than can be cleaned safely: app data in
Application Support and containers (e.g. Docker's disk image), swap, `/private/var`,
APFS snapshots and purgeable space. The **Storage Breakdown** screen measures those
locations (read-only), lists the largest app-data folders and hidden `~/.` folders, and
links to the cleanup category that covers each one where there is one.

## Architecture (MVVM)

```
CleanMe/
├── CleanMeApp.swift          App entry, window + Settings scenes
├── Modules/                  One folder per screen: View + ViewModel (+ Subviews)
│   ├── Root/                 NavigationSplitView, sidebar, report sheet, cleaning overlay
│   ├── Dashboard/            Disk overview, category list, Clean bar
│   ├── Insights/             Storage Breakdown (read-only analysis)
│   ├── CategoryDetail/       Item table for one category
│   ├── CleanupReport/        Result sheet after cleaning
│   └── Settings/             Preferences window (⌘,)
├── Components/               Reusable UI used by several screens
├── Infrastructure/
│   ├── Store/                CleanupStore (results, selection, scan/clean), InsightsStore
│   ├── FileSystem/           Scanner, cleaner, size calculator, path safety validator
│   ├── System/               Disk space, Full Disk Access, tmutil, simctl, admin runner, NSWorkspace
│   ├── Persistence/          UserDefaults-backed settings
│   ├── Concurrency/          Background work helper
│   └── DependencyContainer   Builds and wires services
├── Models/                   Plain Sendable value types
├── Constants/                Paths, keys, layout metrics
└── Resources/                Assets
```

View models only talk to the `CleanupStore` and to services through protocols,
so each one can be tested with fakes.

## Safety

- Only the *children* of known root folders are removed, never the folders themselves.
- `PathSafetyValidator` re-checks every path against its category roots right before deletion.
- Symlinks are never followed (when measuring or deleting).
- iCloud/CloudKit-related cache folders are excluded.
- Default mode is **Move to Trash**. System-owned items, which need an admin password, are always deleted permanently.

## Requirements

- **The App Sandbox is disabled.** A sandboxed app only sees its own container, so it can't reach `~/Library/Caches` and similar folders. That also means the app can't go on the Mac App Store as it is.
- **Full Disk Access** is optional and needed only for TCC-protected folders (Mail).
  The app detects it and links straight to the right pane in System Settings.
- Admin actions use `osascript … with administrator privileges`, which shows the standard macOS password dialog.
