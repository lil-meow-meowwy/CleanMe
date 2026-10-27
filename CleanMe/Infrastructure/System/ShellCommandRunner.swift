import Foundation

nonisolated protocol ShellCommandRunning: Sendable {
    /// Runs an executable and returns its standard output. Throws on a non-zero exit status.
    func run(_ executablePath: String, arguments: [String], environment: [String: String]) async throws -> String
}

extension ShellCommandRunning {
    nonisolated func run(_ executablePath: String, arguments: [String]) async throws -> String {
        try await run(executablePath, arguments: arguments, environment: [:])
    }
}

nonisolated enum ShellError: LocalizedError {
    case launchFailed(String)
    case nonZeroExit(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            "The command couldn't be started: \(reason)"
        case .nonZeroExit(let code, let message):
            message.isEmpty ? "The command failed with exit code \(code)." : message
        }
    }
}

nonisolated struct ShellCommandRunner: ShellCommandRunning {
    func run(_ executablePath: String, arguments: [String], environment: [String: String]) async throws -> String {
        try await BackgroundWork.runThrowing {
            let process = Process()
            process.executableURL = URL(filePath: executablePath)
            process.arguments = arguments
            process.environment = Self.environment(adding: environment)

            let output = Pipe()
            let errorOutput = Pipe()
            process.standardOutput = output
            process.standardError = errorOutput

            do {
                try process.run()
            } catch {
                throw ShellError.launchFailed(error.localizedDescription)
            }

            // Drain stderr on another thread so a full pipe can never block the process.
            let errorBuffer = DataBuffer()
            let errorReader = DispatchGroup()
            errorReader.enter()
            DispatchQueue.global(qos: .utility).async {
                errorBuffer.data = errorOutput.fileHandleForReading.readDataToEndOfFile()
                errorReader.leave()
            }

            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            errorReader.wait()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let message = String(decoding: errorBuffer.data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ShellError.nonZeroExit(code: process.terminationStatus, message: message)
            }
            return String(decoding: outputData, as: UTF8.self)
        }
    }

    /// GUI apps get a minimal PATH; add the usual Homebrew locations so tools find their helpers.
    private static func environment(adding extra: [String: String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let currentPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (AppConstants.Tools.additionalPaths + [currentPath]).joined(separator: ":")
        environment.merge(extra) { _, new in new }
        return environment
    }
}

/// Written by one thread, read after `DispatchGroup.wait()`.
nonisolated private final class DataBuffer: @unchecked Sendable {
    var data = Data()
}

nonisolated enum ShellEscaping {
    /// Wraps a value in single quotes for `/bin/sh`, escaping embedded quotes.
    static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a value for use inside an AppleScript string literal.
    static func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Parses human-readable sizes printed by CLI tools ("1.23GB", "512 MB", "4.1kB").
nonisolated enum ByteSizeParser {
    private static let pattern = try? NSRegularExpression(
        pattern: #"([0-9]+(?:[.,][0-9]+)?)\s*([KMGTP]?i?B)\b"#,
        options: [.caseInsensitive]
    )

    /// The first size found in `text`.
    static func firstSize(in text: String) -> Int64? {
        guard let pattern,
              let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[numberRange].replacingOccurrences(of: ",", with: "."))
        else { return nil }

        let unit = text[unitRange].uppercased()
        let isBinary = unit.contains("I")
        let base: Double = isBinary ? 1024 : 1000
        let exponent: Double = switch unit.first ?? "B" {
        case "K": 1
        case "M": 2
        case "G": 3
        case "T": 4
        case "P": 5
        default: 0
        }
        return Int64(value * pow(base, exponent))
    }
}
