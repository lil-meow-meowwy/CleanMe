import SwiftUI

/// A checkbox that can also show a "mixed" state for partially selected groups.
struct SelectionCheckbox: View {
    let state: SelectionState
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: state.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    state == .none
                        ? AnyShapeStyle(HierarchicalShapeStyle.secondary)
                        : AnyShapeStyle(TintShapeStyle())
                )
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("Select")
        .accessibilityValue(state.accessibilityValue)
    }
}

private extension SelectionState {
    var symbolName: String {
        switch self {
        case .none: "square"
        case .partial: "minus.square.fill"
        case .all: "checkmark.square.fill"
        }
    }

    var accessibilityValue: String {
        switch self {
        case .none: "Not selected"
        case .partial: "Partially selected"
        case .all: "Selected"
        }
    }
}

#Preview {
    HStack {
        SelectionCheckbox(state: .none) {}
        SelectionCheckbox(state: .partial) {}
        SelectionCheckbox(state: .all) {}
        SelectionCheckbox(state: .all, isEnabled: false) {}
    }
    .padding()
}
