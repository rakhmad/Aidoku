//
//  ContentView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

enum SidebarSelection: Hashable {
    case library
    case search
    case downloads
    case source(String) // Store source key, not Source object
}

struct ContentView: View {
    @State private var selection: SidebarSelection? = .library

    var body: some View {
        NavigationSplitView {
            CombinedSidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .library:
                MacLibraryView()
            case .search:
                GlobalSearchView()
            case .downloads:
                DownloadsView()
            case .source(let sourceKey):
                if let source = SourceManager.shared.source(for: sourceKey) {
                    SourceBrowseView(source: source)
                        .id(source.key)
                } else {
                    Text("Source not found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .none:
                Text("Select a section")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Combined Sidebar with Library + Sources
struct CombinedSidebarView: View {
    @Binding var selection: SidebarSelection?
    @State private var sources: [AidokuRunner.Source] = []
    @State private var isShowingAddSheet = false

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Library", systemImage: "books.vertical")
                    .tag(SidebarSelection.library)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarSelection.search)
                Label("Downloads", systemImage: "arrow.down.circle")
                    .tag(SidebarSelection.downloads)
            }

            Section("Sources") {
                ForEach(sources, id: \.key) { source in
                    Label(source.name, systemImage: "doc.text")
                        .tag(SidebarSelection.source(source.key))
                        .contextMenu {
                            Button("Remove Source", role: .destructive) {
                                SourceManager.shared.remove(source: source)
                                sources = SourceManager.shared.sources
                                if case .source(let selectedKey) = selection, selectedKey == source.key {
                                    selection = .library
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle("Aidoku")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingAddSheet = true
                } label: {
                    Label("Add Source", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddSourceListSheet {
                sources = SourceManager.shared.sources
            }
        }
        .onAppear {
            sources = SourceManager.shared.sources
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("updateSourceList"))) { _ in
            sources = SourceManager.shared.sources
        }
    }
}
