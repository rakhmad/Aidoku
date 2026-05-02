//
//  MacLibraryView.swift
//  Aidoku (macOS)
//
//  Created by Skitty on 1/2/22.
//

import AidokuRunner
import SwiftUI

struct MacLibraryView: View {
    @State private var libraryManga: [LibraryMangaItem] = []
    @State private var selectedManga: LibraryMangaItem?
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading Library…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if libraryManga.isEmpty {
                ContentUnavailableView(
                    "No Manga in Library",
                    systemImage: "books.vertical",
                    description: Text("Add manga to your library from the sources tab.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(libraryManga, id: \.id) { item in
                            Button {
                                selectedManga = item
                            } label: {
                                LibraryMangaCoverItem(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await MangaManager.shared.removeFromLibrary(
                                            sourceId: item.sourceId,
                                            mangaId: item.manga.key
                                        )
                                        await loadLibrary()
                                    }
                                } label: {
                                    Label("Remove from Library", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Library")
        // sheet(item:) guarantees item is non-nil when the closure runs,
        // avoiding the state-timing blank that sheet(isPresented:) + if-let causes on macOS
        .sheet(item: $selectedManga) { item in
            if let source = SourceManager.shared.source(for: item.sourceId) {
                MangaDetailView(source: source, manga: item.manga)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Source not available")
                        .font(.headline)
                    Text("The source for \"\(item.manga.title)\" is not installed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close") { selectedManga = nil }
                        .buttonStyle(.borderedProminent)
                }
                .frame(width: 360, height: 200)
                .padding()
            }
        }
        .task {
            await loadLibrary()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("updateSourceList"))) { _ in
            Task { await loadLibrary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("addToLibrary"))) { _ in
            Task { await loadLibrary() }
        }
    }

    @MainActor
    private func loadLibrary() async {
        isLoading = true
        defer { isLoading = false }

        let libraryObjects = CoreDataManager.shared.getLibraryManga()
        var items: [LibraryMangaItem] = []

        for obj in libraryObjects {
            guard let mangaObject = obj.manga else { continue }
            
            // Convert MangaObject to AidokuRunner.Manga
            let manga = mangaObject.toNewManga()
            
            // Get the source
            let source = SourceManager.shared.source(for: mangaObject.sourceId)
            
            items.append(LibraryMangaItem(
                id: "\(mangaObject.sourceId)-\(mangaObject.id)",
                sourceId: mangaObject.sourceId,
                manga: manga,
                source: source,
                dateAdded: obj.dateAdded
            ))
        }

        // Sort by most recently added
        libraryManga = items.sorted { $0.dateAdded > $1.dateAdded }
    }
}

// MARK: - Library Manga Item Model
struct LibraryMangaItem: Identifiable {
    let id: String
    let sourceId: String
    let manga: AidokuRunner.Manga
    let source: AidokuRunner.Source?
    let dateAdded: Date
}

// MARK: - Library Cover Item View
private struct LibraryMangaCoverItem: View {
    let item: LibraryMangaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let source = item.source {
                MacImageView(
                    source: source,
                    imageUrl: item.manga.cover ?? "",
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
            } else {
                // Fallback if source is not available
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(item.manga.title)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
        }
    }
}

#Preview {
    NavigationStack {
        MacLibraryView()
    }
}
