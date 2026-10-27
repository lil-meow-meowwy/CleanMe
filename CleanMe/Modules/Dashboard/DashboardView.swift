import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    private let onSelectCategory: (CleanupCategory) -> Void

    init(viewModel: DashboardViewModel, onSelectCategory: @escaping (CleanupCategory) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectCategory = onSelectCategory
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

                StorageOverviewCard(
                    diskSpace: viewModel.diskSpace,
                    reclaimableBytes: viewModel.reclaimableBytes,
                    selectedBytes: viewModel.selectedBytes
                )

                if viewModel.hasResults || viewModel.isScanning {
                    categoryList
                } else {
                    EmptyStateView(
                        systemImage: "sparkle.magnifyingglass",
                        title: "Not scanned yet",
                        message: "Scan your Mac to see which caches, logs and backups make up System Data.",
                        actionTitle: "Scan Now",
                        action: { viewModel.scanTapped() }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, Layout.sectionSpacing)
                }
            }
            .padding(Layout.contentPadding)
            .frame(maxWidth: Layout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasResults {
                cleanBar
            }
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.scanTapped()
                } label: {
                    if viewModel.isScanning {
                        Label("Stop", systemImage: "stop.circle")
                    } else {
                        Label(viewModel.scanButtonTitle, systemImage: "arrow.clockwise")
                    }
                }
                .help(viewModel.isScanning ? "Stop scanning" : "Scan System Data")
            }
        }
        .confirmationDialog(
            viewModel.cleanupPlan.title,
            isPresented: $viewModel.isConfirmingCleanup,
            titleVisibility: .visible
        ) {
            Button("Clean", role: .destructive) { viewModel.confirmCleanup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.cleanupPlan.message)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.headline)
                .font(.largeTitle.weight(.bold))
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.headline)
            Text(viewModel.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.isScanning {
                ProgressView(value: viewModel.scanProgress)
                    .padding(.top, 6)
            }
        }
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            ForEach(viewModel.groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(group.categories) { category in
                            CategoryRowView(
                                category: category,
                                sizeText: viewModel.sizeText(for: category),
                                isPending: viewModel.isPending(category),
                                selectionState: viewModel.selectionState(for: category),
                                isSelectable: viewModel.canSelect(category),
                                onToggle: { viewModel.toggle(category) },
                                onOpen: { onSelectCategory(category) }
                            )
                            if category != group.categories.last {
                                Divider().padding(.leading, 76)
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
    }

    private var cleanBar: some View {
        HStack(spacing: Layout.rowSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedSizeText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(viewModel.selectionSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.cleanTapped()
            } label: {
                Label("Clean", systemImage: "sparkles")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canClean)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, Layout.contentPadding)
        .frame(maxWidth: Layout.contentMaxWidth)
        .padding(.vertical, Layout.rowSpacing)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .animation(.default, value: viewModel.selectedBytes)
    }
}
