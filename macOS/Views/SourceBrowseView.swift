//
//  SourceBrowseView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct SourceBrowseView: View {
    let source: AidokuRunner.Source

    @State private var listings: [AidokuRunner.Listing] = []
    @State private var selectedListing: AidokuRunner.Listing?
    @State private var entries: [AidokuRunner.Manga] = []
    @State private var isLoading = false
    @State private var hasMore = false
    @State private var page = 1
    @State private var loadError: Error?
    @State private var selectedManga: AidokuRunner.Manga?
    @State private var isShowingDetail = false
    @State private var searchText = ""
    @State private var isSearching = false

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            if !listings.isEmpty && !isSearching {
                Picker("Listing", selection: $selectedListing) {
                    ForEach(listings, id: \.id) { listing in
                        Text(listing.name).tag(Optional(listing))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
            }

            ZStack {
                if isLoading && entries.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError, entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await load(initial: true) }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(entries, id: \.key) { manga in
                                Button {
                                    selectedManga = manga
                                    isShowingDetail = true
                                } label: {
                                    MangaCoverItem(
                                        source: source,
                                        manga: manga
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if hasMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .onAppear {
                                        Task { await load(initial: false) }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(source.name)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(source.name)…")
        .onSubmit(of: .search) {
            Task { await load(initial: true) }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                isSearching = false
                Task { await load(initial: true) }
            }
        }
        .sheet(isPresented: $isShowingDetail) {
            if let manga = selectedManga {
                MangaDetailView(source: source, manga: manga)
            }
        }
        .task {
            listings = (try? await source.getListings()) ?? []
            selectedListing = listings.first
            await load(initial: true)
        }
        .onChange(of: selectedListing) { _ in
            if !isSearching { Task { await load(initial: true) } }
        }
    }

    private func load(initial: Bool) async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let searching = !query.isEmpty
        if initial {
            page = 1
            entries = []
            loadError = nil
            isSearching = searching
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result: AidokuRunner.MangaPageResult
            if searching {
                result = try await source.getSearchMangaList(query: query, page: page, filters: [])
            } else if let listing = selectedListing {
                result = try await source.getMangaList(listing: listing, page: page)
            } else {
                result = try await source.getSearchMangaList(query: nil, page: page, filters: [])
            }
            hasMore = result.hasNextPage
            entries = initial ? result.entries : entries + result.entries
            page += 1
        } catch {
            loadError = error
        }
    }
}

private struct MangaCoverItem: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MacImageView(
                source: source,
                imageUrl: manga.cover ?? "",
                contentMode: .fill
            )
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )

            Text(manga.title)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
        }
    }
}
