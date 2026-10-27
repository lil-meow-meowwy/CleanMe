import SwiftUI

/// Explains why Full Disk Access is needed and links to System Settings.
struct PermissionBannerView: View {
    var title = "Full Disk Access is off"
    let message: String
    var actionTitle = "Open Privacy Settings…"
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button(actionTitle, action: action)
                .fixedSize()
        }
        .padding(Layout.rowSpacing)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

#Preview {
    PermissionBannerView(
        message: "Some locations can't be scanned until you allow CleanMe in System Settings."
    ) {}
    .padding()
    .frame(width: 600)
}
