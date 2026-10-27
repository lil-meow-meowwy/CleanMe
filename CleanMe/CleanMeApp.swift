import SwiftUI

@main
struct CleanMeApp: App {
    @State private var dependencies = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: RootViewModel(dependencies: dependencies))
                .frame(minWidth: Layout.windowMinWidth, minHeight: Layout.windowMinHeight)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan System Data") {
                    dependencies.store.startScan()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView(
                viewModel: SettingsViewModel(
                    settings: dependencies.settings,
                    workspace: dependencies.workspace
                )
            )
        }
    }
}
