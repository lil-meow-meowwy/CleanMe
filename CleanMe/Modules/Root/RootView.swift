import AppKit
import Combine
import SwiftUI

struct RootView: View {
    @State private var viewModel: RootViewModel

    init(viewModel: RootViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .overlay {
            if viewModel.isCleaning {
                ActivityOverlay(title: "Cleaning…")
            }
        }
        .animation(.default, value: viewModel.isCleaning)
        .sheet(item: $viewModel.presentedReport) { report in
            CleanupReportView(viewModel: viewModel.makeReportViewModel(for: report))
        }
        .onAppear { viewModel.onAppear() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.appDidBecomeActive()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selection) {
            Label("Overview", systemImage: "gauge.with.dots.needle.33percent")
                .tag(RootViewModel.Destination.overview)
            Label("Storage Breakdown", systemImage: "chart.pie")
                .tag(RootViewModel.Destination.insights)

            ForEach(viewModel.groups) { group in
                Section(isExpanded: expansion(for: group)) {
                    ForEach(group.categories) { category in
                        SidebarCategoryRow(
                            category: category,
                            sizeText: viewModel.sizeText(for: category),
                            isPending: viewModel.isPending(category)
                        )
                        .tag(RootViewModel.Destination.category(category))
                    }
                } header: {
                    HStack {
                        Text(group.title)
                        Spacer()
                        if let size = viewModel.sizeText(for: group) {
                            Text(size)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        // Only scroll (and rubber-band) when the content really doesn't fit.
        .scrollBounceBehavior(.basedOnSize)
        .navigationSplitViewColumnWidth(min: Layout.sidebarMinWidth, ideal: Layout.sidebarIdealWidth)
    }

    private func expansion(for group: CategoryGroup) -> Binding<Bool> {
        Binding(
            get: { viewModel.isExpanded(group) },
            set: { viewModel.setExpanded(group, $0) }
        )
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selection ?? .overview {
        case .overview:
            DashboardView(viewModel: viewModel.makeDashboardViewModel()) { category in
                viewModel.selection = .category(category)
            }
        case .insights:
            InsightsView(viewModel: viewModel.makeInsightsViewModel()) { category in
                viewModel.selection = .category(category)
            }
        case .category(let category):
            CategoryDetailView(viewModel: viewModel.makeCategoryDetailViewModel(for: category))
                .id(category)
        }
    }
}
