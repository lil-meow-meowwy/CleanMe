import Foundation
import Observation

/// Holds the last Storage Breakdown so it survives navigating between screens.
@Observable
final class InsightsStore {
    private(set) var report: StorageInsightsReport?
    private(set) var isAnalyzing = false

    @ObservationIgnored private let scanner: any StorageInsightsScanning
    @ObservationIgnored private var task: Task<Void, Never>?

    init(scanner: any StorageInsightsScanning) {
        self.scanner = scanner
    }

    func analyze() {
        task?.cancel()
        isAnalyzing = true
        let scanner = self.scanner

        task = Task {
            let report = await scanner.analyze()
            guard !Task.isCancelled else { return }
            self.report = report
            isAnalyzing = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isAnalyzing = false
    }
}
