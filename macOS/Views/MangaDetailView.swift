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
            await loadDetails()
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
