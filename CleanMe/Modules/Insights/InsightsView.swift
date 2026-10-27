import SwiftUI

struct InsightsView: View {
    @State private var viewModel: InsightsViewModel
    private let onOpenCategory: (CleanupCategory) -> Void

    init(viewModel: InsightsViewModel, onOpenCategory: @escaping (CleanupCategory) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenCategory = onOpenCategory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                header

                if viewModel.showsPermissionBanner {
                    PermissionBannerView(message: viewModel.permissionMessage) {
                        viewModel.openFullDiskAccessSettings()
                    }
                }

                explanationCard

                if viewModel.isAnalyzing {
                    ActivityOverlay(title: "Measuring folders…", dimsBackground: false)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Layout.sectionSpacing)
                } else if viewModel.hasReport {
                    section("Where System Data lives", items: viewModel.locations)
                    section("Largest app data folders", items: viewModel.largestItems)
                    if !viewModel.hiddenFolders.isEmpty {
                        section("Hidden folders in your home", items: viewModel.hiddenFolders)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "chart.pie",
                        title: "No breakdown yet",
                        message: "Measure the folders behind System Data to see what takes up the space.",
                        actionTitle: "Analyze",
                        action: { viewModel.analyzeTapped() }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Layout.contentPadding)
            .frame(maxWidth: Layout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Storage Breakdown")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.analyzeTapped()
                } label: {
                    if viewModel.isAnalyzing {
                        Label("Stop", systemImage: "stop.circle")
                    } else {
                        Label(viewModel.analyzeButtonTitle, systemImage: "chart.pie")
                    }
                }
                .help(viewModel.isAnalyzing ? "Stop measuring" : "Measure System Data folders")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.headline)
                .font(.largeTitle.weight(.bold))
            Text(viewModel.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why System Settings shows more", systemImage: "info.circle")
                .font(.headline)
            ForEach(viewModel.explanationNotes, id: \.self) { note in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                    Text(note)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.rowSpacing)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private func openCategoryAction(for insight: StorageInsight) -> (() -> Void)? {
        guard let category = insight.relatedCategory else { return nil }
        return { onOpenCategory(category) }
    }

    private func section(_ title: String, items: [StorageInsight]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(items) { insight in
                    InsightRowView(
                        insight: insight,
                        sizeText: viewModel.sizeText(for: insight),
                        fraction: viewModel.fraction(for: insight, in: items),
                        onReveal: { viewModel.reveal(insight) },
                        onOpenCategory: openCategoryAction(for: insight)
                    )
                    if insight.id != items.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(.background.secondary)
            )
        }
    }
}
