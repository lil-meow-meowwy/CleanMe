import SwiftUI

struct CleanupReportView: View {
    @State private var viewModel: CleanupReportViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CleanupReportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(viewModel.isSuccess ? Color.green : Color.orange)
                .symbolEffect(.bounce, value: viewModel.report.id)

            VStack(spacing: 4) {
                Text(viewModel.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(viewModel.subtitle)
                    .foregroundStyle(.secondary)
            }

            if viewModel.showsTrashHint {
                VStack(spacing: 8) {
                    Text(viewModel.trashHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Trash") { viewModel.openTrash() }
                }
            }

            if !viewModel.failures.isEmpty {
                failureList
            }

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(Layout.contentPadding)
        .frame(width: 440)
    }

    private var failureList: some View {
        GroupBox {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(failure.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 160)
        } label: {
            Text(viewModel.failuresTitle)
        }
    }
}
