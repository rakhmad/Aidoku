//
//  GlobalSearchView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct GlobalSearchView: View {
    @State private var searchText = ""
    @State private var sourceResults: [SourceResult] = []
    @State private var hasSearched = false
    @State private var selectedManga: MangaSelection?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if !hasSearched {
                placeholder
            } else {
                resultsView
            }
        }
        .navigationTitle("Search")
        .sheet(item: $selectedManga) { sel in
            MangaDetailView(source: sel.source, manga: sel.manga)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search all sources…", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit { Task { await search() } }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    hasSearched = false
                    sourceResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        let count = SourceManager.shared.sources.count
        return VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(count == 0
                 ? "No sources installed"
                 : "Search across \(count) source\(count == 1 ? "" : "s")")
                .font(.headline)
                .foregroundStyle(.secondary)
            if count > 0 {
                Text("Type a title and press Return")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsView: some View {
        let allDone = sourceResults.allSatisfy { !$0.isLoading }
        let hasAny = sourceResults.contains { !$0.entries.isEmpty }

        if allDone && !hasAny {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No results found")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sourceResults) { result in
                        if result.isLoading || !result.entries.isEmpty {
                            SourceResultSection(result: result) { manga in
                                selectedManga = MangaSelection(source: result.source, manga: manga)
                            }
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Search

    @MainActor
    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        hasSearched = true
        let sources = SourceManager.shared.sources
        guard !sources.isEmpty else { return }
        sourceResults = sources.map { SourceResult(id: $0.key, source: $0) }
        await withTaskGroup(of: (String, [AidokuRunner.Manga]).self) { group in
            for source in sources {
                group.addTask {
                    let result = try? await source.getSearchMangaList(query: query, page: 1, filters: [])
                    return (source.key, result?.entries ?? [])
                }
            }
            for await (key, entries) in group {
                if let idx = sourceResults.firstIndex(where: { $0.id == key }) {
                    sourceResults[idx].entries = entries
                    sourceResults[idx].isLoading = false
                }
            }
        }
    }
}

// MARK: - Models

private struct SourceResult: Identifiable {
    let id: String
    let source: AidokuRunner.Source
    var entries: [AidokuRunner.Manga] = []
    var isLoading = true
}

private struct MangaSelection: Identifiable {
    let id = UUID()
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga
}

// MARK: - Per-source row

private struct SourceResultSection: View {
    let result: SourceResult
    let onSelect: (AidokuRunner.Manga) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(result.source.name)
                    .font(.headline)
                if result.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("(\(result.entries.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !result.isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(result.entries.prefix(15), id: \.key) { manga in
                            Button {
                                onSelect(manga)
                            } label: {
                                SearchMangaItem(source: result.source, manga: manga)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            } else {
                Color.clear.frame(height: 40)
            }
        }
    }
}

// MARK: - Manga cover item

private struct SearchMangaItem: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MacImageView(source: source, imageUrl: manga.cover ?? "", contentMode: .fill)
                .frame(width: 100, height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Text(manga.title)
                .font(.system(size: 11))
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}
