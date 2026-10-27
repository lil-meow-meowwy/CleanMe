import Foundation

nonisolated enum DockerStatus: Sendable {
    case notInstalled
    case notRunning
    /// Reclaimable bytes per resource type.
    case running([DockerResource: Int64])
}

nonisolated protocol DeveloperToolsManaging: Sendable {
    func dockerStatus() async -> DockerStatus
    func pruneDocker(_ resource: DockerResource) async throws
    /// `nil` when Homebrew isn't installed.
    func homebrewReclaimableBytes() async -> Int64?
    func runHomebrewCleanup() async throws
}

/// Wraps the Docker and Homebrew command-line tools.
nonisolated struct DeveloperToolsService: DeveloperToolsManaging {
    private nonisolated enum ToolError: LocalizedError {
        case notInstalled(String)
        var errorDescription: String? {
            switch self {
            case .notInstalled(let tool): "\(tool) isn't installed."
            }
        }
    }

    private let shell: any ShellCommandRunning

    init(shell: any ShellCommandRunning) {
        self.shell = shell
    }

    // MARK: - Docker

    func dockerStatus() async -> DockerStatus {
        guard let docker = Self.executable(from: AppConstants.Tools.dockerCandidates) else { return .notInstalled }
        guard let output = try? await shell.run(
            docker,
            arguments: ["system", "df", "--format", "{{json .}}"]
        ) else { return .notRunning }

        // One JSON object per line: {"Type":"Images","Reclaimable":"1.2GB (50%)",…}
        var reclaimable: [DockerResource: Int64] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["Type"] as? String,
                  let resource = DockerResource(rawValue: type),
                  let text = object["Reclaimable"] as? String
            else { continue }
            reclaimable[resource] = ByteSizeParser.firstSize(in: text) ?? 0
        }
        return .running(reclaimable)
    }

    func pruneDocker(_ resource: DockerResource) async throws {
        guard let docker = Self.executable(from: AppConstants.Tools.dockerCandidates) else {
            throw ToolError.notInstalled("Docker")
        }
        _ = try await shell.run(docker, arguments: resource.pruneArguments)
    }

    // MARK: - Homebrew

    func homebrewReclaimableBytes() async -> Int64? {
        guard let brew = Self.executable(from: AppConstants.Tools.homebrewCandidates) else { return nil }
        guard let output = try? await shell.run(
            brew,
            arguments: AppConstants.Tools.homebrewDryRunArguments,
            environment: AppConstants.Tools.homebrewEnvironment
        ) else { return 0 }

        // "==> This operation would free approximately 1.2GB of disk space."
        guard let line = output.split(whereSeparator: \.isNewline).last(where: { $0.contains("would free") }) else {
            return 0
        }
        return ByteSizeParser.firstSize(in: String(line)) ?? 0
    }

    func runHomebrewCleanup() async throws {
        guard let brew = Self.executable(from: AppConstants.Tools.homebrewCandidates) else {
            throw ToolError.notInstalled("Homebrew")
        }
        _ = try await shell.run(
            brew,
            arguments: AppConstants.Tools.homebrewCleanupArguments,
            environment: AppConstants.Tools.homebrewEnvironment
        )
    }

    // MARK: - Helpers

    private static func executable(from candidates: [String]) -> String? {
        candidates
            .map { ($0 as NSString).expandingTildeInPath }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
