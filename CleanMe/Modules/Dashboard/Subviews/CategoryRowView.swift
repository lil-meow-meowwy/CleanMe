import SwiftUI

struct CategoryRowView: View {
    let category: CleanupCategory
    let sizeText: String
    let isPending: Bool
    let selectionState: SelectionState
    let isSelectable: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            SelectionCheckbox(state: selectionState, isEnabled: isSelectable, action: onToggle)

            CategoryIconView(category: category)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.title)
                        .font(.body.weight(.medium))
                    RiskBadge(risk: category.risk)
                }
                Text(category.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: Layout.rowSpacing)

            Group {
                if isPending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(sizeText)
                        .monospacedDigit()
                        .foregroundStyle(["Clean", "Unavailable"].contains(sizeText) ? Color.secondary : Color.primary)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)

            Button(action: onOpen) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Show items")
        }
        .padding(.horizontal, Layout.rowSpacing)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
    }
}
