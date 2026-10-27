import SwiftUI

struct RiskBadge: View {
    let risk: RiskLevel

    var body: some View {
        Text(risk.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(risk.tint)
            .background(risk.tint.opacity(0.15), in: Capsule())
            .help(risk.explanation)
    }
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe: .green
        case .review: .orange
        case .caution: .red
        }
    }
}

#Preview {
    HStack {
        RiskBadge(risk: .safe)
        RiskBadge(risk: .review)
        RiskBadge(risk: .caution)
    }
    .padding()
}
