import Foundation

/// Computes the real on-disk (allocated) size of files and folders.
nonisolated enum FileSizeCalculator {
    nonisolated struct Measurement: Sendable {
        let bytes: Int64
        /// `false` when some children couldn't be read, so `bytes` is a lower bound.
        let isComplete: Bool
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
    ]

    /// Blocking. Call from a background context. Symbolic links are never followed.
    static func allocatedSize(of url: URL) -> Int64 {
        measure(url).bytes
    }

    /// Blocking. Call from a background context. Symbolic links are never followed.
    static func measure(_ url: URL) -> Measurement {
        let keySet = Set(resourceKeys)
        guard let values = try? url.resourceValues(forKeys: keySet) else {
            return Measurement(bytes: 0, isComplete: false)
        }
        if values.isSymbolicLink == true { return Measurement(bytes: 0, isComplete: true) }
        guard values.isDirectory == true else {
            return Measurement(bytes: size(from: values), isComplete: true)
        }

        let errors = ErrorFlag()
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: { _, _ in
                errors.occurred = true
                return true // Skip unreadable children, keep going.
            }
        ) else { return Measurement(bytes: 0, isComplete: false) }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            guard let childValues = try? fileURL.resourceValues(forKeys: keySet),
                  childValues.isRegularFile == true
            else { continue }
            total += size(from: childValues)
        }
        return Measurement(bytes: total, isComplete: !errors.occurred)
    }

    private static func size(from values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}

/// Mutable flag captured by the enumerator's error handler (used on one thread only).
nonisolated private final class ErrorFlag: @unchecked Sendable {
    var occurred = false
}
