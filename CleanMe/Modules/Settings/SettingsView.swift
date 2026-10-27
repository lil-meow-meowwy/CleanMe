import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Cleaning") {
                Picker("Removed items", selection: $viewModel.deletionMode) {
                    ForEach(viewModel.deletionModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(viewModel.deletionMode.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Ask for confirmation before cleaning", isOn: $viewModel.confirmBeforeCleaning)
            }

            Section("Scanning") {
                Stepper(value: $viewModel.temporaryFileMinimumAgeDays, in: viewModel.temporaryFileAgeRange) {
                    Text("Skip temporary files newer than ^[\(viewModel.temporaryFileMinimumAgeDays) day](inflect: true)")
                }
            }

            Section("Permissions") {
                LabeledContent("Full Disk Access") {
                    Button("Open Privacy Settings…") { viewModel.openFullDiskAccessSettings() }
                }
                Text("Needed to scan protected locations such as Mail downloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
