import SwiftUI

struct CategoryDetailView: View {
    @State private var viewModel: CategoryDetailViewModel

    init(viewModel: CategoryDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            CategoryHeaderView(
                category: viewModel.category,
                totalSizeText: viewModel.totalSizeText,
                locationsText: viewModel.locationsText,
                canOpenLocation: viewModel.canRevealLocation,
                onOpenLocation: { viewModel.openLocation() }
            )
            .padding(Layout.contentPadding)
            .frame(maxWidth: Layout.contentMaxWidth)
            .frame(maxWidth: .infinity)

            if viewModel.showsPermissionBanner {
                PermissionBannerView(message: viewModel.permissionMessage) {
                    viewModel.openFullDiskAccessSettings()
                }
                .padding(.horizontal, Layout.contentPadding)
                .frame(maxWidth: Layout.contentMaxWidth)
                .padding(.bottom, Layout.rowSpacing)
                .frame(maxWidth: .infinity)
            }

            if let notice = viewModel.notice {
                Label(notice, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Layout.contentPadding)
                    .frame(maxWidth: Layout.contentMaxWidth)
                    .padding(.bottom, Layout.rowSpacing)
                    .frame(maxWidth: .infinity)
            }

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.hasResult && !viewModel.isEmpty {
                footer
            }
        }
        // Never let the content's ideal height grow the window; extra space goes to the table.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(viewModel.category.title)
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Filter items")
        .toolbar {
            ToolbarItem {
                Picker("Sort By", selection: $viewModel.sortOption) {
                    ForEach(CategoryDetailViewModel.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .help("Sort items")
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ActivityOverlay(title: "Scanning \(viewModel.category.title)…", dimsBackground: false)
        } else if !viewModel.hasResult {
            EmptyStateView(
                systemImage: "sparkle.magnifyingglass",
                title: "Not scanned yet",
                message: "Scan your Mac to see what's in \(viewModel.category.title).",
                actionTitle: "Scan Now",
                action: { viewModel.scan() }
            )
        } else if viewModel.isEmpty {
            EmptyStateView(
                systemImage: "checkmark.seal",
                title: "Nothing to clean",
                message: "Nothing in \(viewModel.category.title) is taking up space right now."
            )
        } else if viewModel.items.isEmpty && viewModel.isFiltering {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            itemsTable
        }
    }

    private var itemsTable: some View {
        Table(viewModel.items) {
            TableColumn("") { item in
                SelectionCheckbox(
                    state: viewModel.isSelected(item) ? .all : .none,
                    isEnabled: !viewModel.isBusy,
                    action: { viewModel.toggle(item) }
                )
            }
            .width(24)

            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Text(item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let detail = item.detail {
                        Text(detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .help(item.path)
            }

            TableColumn("Size") { item in
                Text(viewModel.sizeText(for: item))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 140)

            TableColumn("Modified") { item in
                Text(viewModel.dateText(for: item))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 160, max: 200)

            TableColumn("") { item in
                if item.url != nil {
                    Button {
                        viewModel.reveal(item)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
            }
            .width(24)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        HStack(spacing: Layout.rowSpacing) {
            SelectionCheckbox(
                state: viewModel.selectionState,
                isEnabled: !viewModel.isBusy,
                action: { viewModel.toggleAll() }
            )
            Text(viewModel.selectionState == .all ? "Deselect All" : "Select All")
                .onTapGesture { viewModel.toggleAll() }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.selectedSizeText)
                    .font(.headline)
                    .monospacedDigit()
                Text(viewModel.selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.cleanTapped()
            } label: {
                Label("Clean", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canClean)
        }
        .padding(.horizontal, Layout.contentPadding)
        .frame(maxWidth: Layout.contentMaxWidth)
        .padding(.vertical, Layout.rowSpacing)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
