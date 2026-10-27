import Foundation
import Observation

@Observable
final class CleanupReportViewModel {
    let report: CleanupReport
    @ObservationIgnored private let workspace: any WorkspaceServicing

    init(report: CleanupReport, workspace: any WorkspaceServicing) {
        self.report = report
        self.workspace = workspace
    }

    var isSuccess: Bool { !report.hasFailures }
    var failures: [CleanupReport.Failure] { report.failures }

    var title: String {
        if report.removedCount == 0 { return "Nothing was removed" }
        let size = report.freedBytes.formatted(.byteCount(style: .file))
        return report.mode == .trash ? "\(size) moved to the Trash" : "\(size) cleaned"
    }

    var subtitle: String {
        let noun = report.removedCount == 1 ? "item" : "items"
        return "\(report.removedCount) \(noun) removed."
    }

    var showsTrashHint: Bool {
        report.mode == .trash && report.removedCount > 0
    }

    var trashHint: String {
        "Space is freed once you empty the Trash."
    }

    var failuresTitle: String {
        let noun = failures.count == 1 ? "item" : "items"
        return "\(failures.count) \(noun) couldn't be removed"
    }

    func openTrash() {
        workspace.openTrash()
    }
}
