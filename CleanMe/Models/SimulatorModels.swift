import Foundation

nonisolated struct SimulatorDevice: Sendable {
    let udid: String
    let name: String
    /// Human-readable runtime, e.g. "iOS 18.2".
    let runtime: String
    let directory: URL
    let size: Int64
    let lastModified: Date?
}

nonisolated struct SimulatorRuntime: Sendable {
    let identifier: String
    /// Human-readable name, e.g. "iOS 18.2".
    let name: String
    let build: String?
    let size: Int64?
    let lastUsed: Date?
    let isDeletable: Bool
}
