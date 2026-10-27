import SwiftUI

/// Blocking progress indicator shown on top of content.
struct ActivityOverlay: View {
    let title: String
    var progress: Double?
    var dimsBackground = true

    var body: some View {
        ZStack {
            if dimsBackground {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
            }

            VStack(spacing: Layout.rowSpacing) {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 180)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
                Text(title)
                    .font(.headline)
            }
            .padding(Layout.contentPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
            .shadow(radius: 12, y: 4)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ActivityOverlay(title: "Cleaning…")
        .frame(width: 500, height: 300)
}
