//
//  SourceSidebarView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct SourceSidebarView: View {
    @Binding var selectedSource: AidokuRunner.Source?

    @State private var sources: [AidokuRunner.Source] = []
    @State private var selectedKey: String?
    @State private var showAddSheet = false

    var body: some View {
        List(sources, id: \.key, selection: $selectedKey) { source in
            HStack(spacing: 10) {
                MacImageView(
                    imageUrl: source.imageUrl?.absoluteString ?? "",
                    contentMode: .fill
                )
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(source.languages.first ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tag(source.key)
        }
        .navigationTitle("Sources")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Source List")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSourceListSheet {
                sources = SourceManager.shared.sources
            }
        }
        .onChange(of: selectedKey) { key in
            selectedSource = key.flatMap { SourceManager.shared.source(for: $0) }
        }
        .onAppear {
            sources = SourceManager.shared.sources
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateSourceList)) { _ in
            sources = SourceManager.shared.sources
        }
    }
}
