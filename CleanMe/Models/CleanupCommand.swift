import Foundation

/// Cleanups performed by a command-line tool instead of deleting files directly.
nonisolated enum CleanupCommand: Hashable, Sendable {
    case docker(DockerResource)
    case homebrewCleanup
    case eraseUnifiedLogs

    var id: String {
        switch self {
        case .docker(let resource): "docker.\(resource.rawValue)"
        case .homebrewCleanup: "brew.cleanup"
        case .eraseUnifiedLogs: "log.erase"
        }
    }

    /// The command as shown to the user.
    var displayCommand: String {
        switch self {
        case .docker(let resource): "docker " + resource.pruneArguments.joined(separator: " ")
        case .homebrewCleanup: "brew " + AppConstants.Tools.homebrewCleanupArguments.joined(separator: " ")
        case .eraseUnifiedLogs: "sudo log erase --all"
        }
    }
}

/// The resource types reported by `docker system df`.
nonisolated enum DockerResource: String, CaseIterable, Sendable {
    case images = "Images"
    case containers = "Containers"
    case volumes = "Local Volumes"
    case buildCache = "Build Cache"

    var title: String {
        switch self {
        case .images: "Unused images"
        case .containers: "Stopped containers"
        case .volumes: "Unused volumes (contain data)"
        case .buildCache: "Build cache"
        }
    }

    var pruneArguments: [String] {
        switch self {
        case .images: ["image", "prune", "--all", "--force"]
        case .containers: ["container", "prune", "--force"]
        case .volumes: ["volume", "prune", "--all", "--force"]
        case .buildCache: ["builder", "prune", "--all", "--force"]
        }
    }
}
