import SwiftUI

struct SidebarCategoryRow: View {
    let category: CleanupCategory
    let sizeText: String?
    let isPending: Bool

    var body: some View {
        Label {
            HStack {
                Text(category.title)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isPending {
                    ProgressView()
                        .controlSize(.mini)
                } else if let sizeText {
                    Text(sizeText)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            CategoryIconView(category: category, size: Layout.sidebarIconSize)
        }
    }
}
