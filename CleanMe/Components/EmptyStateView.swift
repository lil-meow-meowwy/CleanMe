import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        systemImage: "magnifyingglass",
        title: "Not scanned yet",
        message: "Scan your Mac to see how much System Data can be removed.",
        actionTitle: "Scan"
    ) {}
}
