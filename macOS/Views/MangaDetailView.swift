//
//  MangaDetailView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct MangaDetailView: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga

    @Environment(\.dismiss) private var dismiss

    @State private var detailedManga: AidokuRunner.Manga?
    @State private var chapters: [AidokuRunner.Chapter] = []
    @State private var isLoading = true
    @State private var loadError: Error?

    @State private var selectedChapter: AidokuRunner.Chapter?
    @State private var isShowingReader = false
    @State private var isInLibrary = false
    @State private var isSubscribing = false

    var displayManga: AidokuRunner.Manga { detailedManga ?? manga }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left panel: cover + metadata
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    MacImageView(
                        source: source,
                        imageUrl: displayManga.cover ?? "",
                        contentMode: .fill
                    )
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(displayManga.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    if let authors = displayManga.authors, !authors.isEmpty {
                        Text(authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await toggleLibrary() }
                    } label: {
                        if isSubscribing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity, minHeight: 28)
                        } else {
                            Label(
                                isInLibrary ? "In Library" : "Add to Library",
                                systemImage: isInLibrary ? "checkmark" : "plus"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isInLibrary ? .secondary : .accentColor)
                    .disabled(isSubscribing)

                    Spacer()
                }
                .padding()
            }
            .frame(width: 190)

            Divider()

            // Right panel: synopsis + chapters
            VStack(alignment: .leading, spacing: 0) {
                // Synopsis
                if let desc = displayManga.description, !desc.isEmpty {
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .padding()
                    Divider()
                }

                // Chapter list
                if isLoading {
                    ProgressView("Loading chapters…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    VStack(spacing: 8) {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadDetails() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if chapters.isEmpty {
                    Text("No chapters found.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(chapters, id: \.key) { chapter in
                        Button {
                            selectedChapter = chapter
                            isShowingReader = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chapter.formattedTitle())
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                    if let subtitle = chapter.formattedSubtitle(
                                        page: nil,
                                        sourceKey: source.key
                                    ) {
                                        Text(subtitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 700, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text(displayManga.title)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .sheet(isPresented: $isShowingReader) {
            if let chapter = selectedChapter {
                WebtoonReaderView(
                    source: source,
                    manga: displayManga,
                    chapter: chapter
                )
            }
        }
        .task {
            isInLibrary = CoreDataManager.shared.hasLibraryManga(
                sourceId: source.key,
                mangaId: manga.key
            )
            await loadDetails()
        }
    }

    private func toggleLibrary() async {
        if isInLibrary {
            isInLibrary = false
            await MangaManager.shared.removeFromLibrary(
                sourceId: source.key,
                mangaId: displayManga.key
            )
        } else {
            isSubscribing = true
            await MangaManager.shared.addToLibrary(
                sourceId: source.key,
                manga: displayManga,
                chapters: chapters
            )
            isSubscribing = false
            isInLibrary = true
        }
    }

    private func loadDetails() async {
        isLoading = true
        loadError = nil
        do {
            let updated = try await source.getMangaUpdate(
                manga: manga,
                needsDetails: true,
                needsChapters: true
            )
            detailedManga = updated
            chapters = updated.chapters ?? []
        } catch {
            loadError = error
        }
        isLoading = false
    }
}
