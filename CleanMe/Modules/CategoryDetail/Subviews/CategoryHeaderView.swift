import SwiftUI

struct CategoryHeaderView: View {
    let category: CleanupCategory
    let totalSizeText: String
    let locationsText: String
    let canOpenLocation: Bool
    let onOpenLocation: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing + 4) {
            CategoryIconView(category: category, size: 52)

            // Takes all remaining width first, so the text never gets squeezed into a
            // narrow, very tall column. Line limits keep the header height bounded.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(category.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    RiskBadge(risk: category.risk)
                }
                Text(category.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(locationsText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 8) {
                Text(totalSizeText)
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                if canOpenLocation {
                    Button("Open in Finder", action: onOpenLocation)
                        .controlSize(.small)
                }
            }
            .fixedSize()
        }
    }
}

#Preview {
    CategoryHeaderView(
        category: .simulatorRuntimes,
        totalSizeText: "23.4 GB",
        locationsText: "/Library/Developer/CoreSimulator (via simctl)",
        canOpenLocation: true,
        onOpenLocation: {}
    )
    .padding()
    .frame(width: 700)
}
