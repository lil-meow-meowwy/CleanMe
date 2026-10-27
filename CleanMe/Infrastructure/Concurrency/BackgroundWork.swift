import Foundation

/// Runs blocking work (file enumeration, process execution) off the main actor,
/// while still forwarding cancellation from the calling task.
nonisolated enum BackgroundWork {
    static func run<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () -> T
    ) async -> T {
        let task = Task.detached(priority: priority) { operation() }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func runThrowing<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: priority) { try operation() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
