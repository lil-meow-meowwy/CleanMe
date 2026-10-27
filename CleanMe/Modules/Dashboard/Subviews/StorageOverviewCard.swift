import SwiftUI

/// Disk usage bar: used space, the part of it that CleanMe can reclaim, and free space.
struct StorageOverviewCard: View {
    let diskSpace: DiskSpaceInfo?
    let reclaimableBytes: Int64
    let selectedBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Label(diskSpace?.volumeName ?? "Startup Disk", systemImage: "internaldrive")
                    .font(.headline)
                Spacer()
                if let diskSpace {
                    Text("\(diskSpace.availableCapacity.formatted(.byteCount(style: .file))) available of \(diskSpace.totalCapacity.formatted(.byteCount(style: .file)))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            bar

            HStack(spacing: Layout.sectionSpacing) {
                legend(color: Color.secondary, title: "Other data")
                legend(color: .orange.opacity(0.5), title: "Cleanable", bytes: reclaimableBytes)
                legend(color: .orange, title: "Selected", bytes: selectedBytes)
            }
            .font(.caption)
        }
        .padding(Layout.contentPadding * 0.75)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(.background.secondary)
        )
    }

    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let used = diskSpace?.usedCapacity ?? 0
            let cleanable = min(reclaimableBytes, used)
            let selected = min(selectedBytes, cleanable)
            let otherFraction = diskSpace?.fraction(of: used - cleanable) ?? 0
            let unselectedFraction = diskSpace?.fraction(of: cleanable - selected) ?? 0
            let selectedFraction = diskSpace?.fraction(of: selected) ?? 0

            HStack(spacing: 0) {
                Rectangle().fill(.secondary).frame(width: width * otherFraction)
                Rectangle().fill(Color.orange.opacity(0.5)).frame(width: width * unselectedFraction)
                Rectangle().fill(Color.orange).frame(width: width * selectedFraction)
                Rectangle().fill(.quaternary)
            }
            .animation(.smooth, value: selectedBytes)
            .animation(.smooth, value: reclaimableBytes)
        }
        .frame(height: Layout.storageBarHeight)
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Disk usage")
    }

    private func legend(color: Color, title: String, bytes: Int64? = nil) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            if let bytes {
                Text(bytes.formatted(.byteCount(style: .file)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    StorageOverviewCard(
        diskSpace: DiskSpaceInfo(volumeName: "Macintosh HD", totalCapacity: 500_000_000_000, availableCapacity: 120_000_000_000),
        reclaimableBytes: 42_000_000_000,
        selectedBytes: 18_000_000_000
    )
    .padding()
    .frame(width: 640)
}
