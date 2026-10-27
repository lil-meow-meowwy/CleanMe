import SwiftUI

/// Rounded, tinted SF Symbol tile representing a cleanup category.
struct CategoryIconView: View {
    let category: CleanupCategory
    var size: CGFloat = Layout.iconSize

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(category.group.tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: category.systemImage)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

extension CategoryGroup {
    var tint: Color {
        switch self {
        case .system: .blue
        case .developer: .indigo
        case .backups: .teal
        }
    }
}

#Preview {
    HStack {
        ForEach(CleanupCategory.allCases) { CategoryIconView(category: $0) }
    }
    .padding()
}
