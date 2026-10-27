import Foundation

nonisolated protocol PermissionChecking: Sendable {
    func hasFullDiskAccess() -> Bool
}

/// macOS has no API to query Full Disk Access, so we probe TCC-protected locations.
nonisolated struct PermissionService: PermissionChecking {
    func hasFullDiskAccess() -> Bool {
        let fileManager = FileManager.default

        return AppConstants.FullDiskAccess.probePaths.contains { rawPath in
            let path = (rawPath as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }

            if isDirectory.boolValue {
                return (try? fileManager.contentsOfDirectory(atPath: path)) != nil
            }
            guard let handle = FileHandle(forReadingAtPath: path) else { return false }
            try? handle.close()
            return true
        }
    }
}
