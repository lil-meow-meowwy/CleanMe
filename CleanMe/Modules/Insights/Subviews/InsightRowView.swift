import SwiftUI

struct InsightRowView: View {
    let insight: StorageInsight
    let sizeText: String
    /// Size relative to the largest row in the same section (0…1).
    let fraction: Double
    let onReveal: () -> Void
    /// Set when a cleanup category covers part of this folder.
    let onOpenCategory: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            Image(systemName: insight.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(insight.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: Layout.rowSpacing)
                    Text(sizeText)
                        .monospacedDigit()
                        .help(insight.isComplete ? "" : "Part of this folder couldn't be read, so the real size is larger.")
                }

                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(.orange)

                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")

                if let onOpenCategory {
                    Button(action: onOpenCategory) {
                        Image(systemName: "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .help("Clean what can be removed safely")
                }
            }
        }
        .padding(.horizontal, Layout.rowSpacing)
        .padding(.vertical, 10)
    }
}
