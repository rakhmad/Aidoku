//
//  ContentView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct ContentView: View {
    @State private var selectedSource: AidokuRunner.Source?

    var body: some View {
        NavigationSplitView {
            SourceSidebarView(selectedSource: $selectedSource)
        } detail: {
            if let source = selectedSource {
                SourceBrowseView(source: source)
                    .id(source.key)
            } else {
                Text("Select a source to browse")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
