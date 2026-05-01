//
//  WebtoonReaderView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct WebtoonReaderView: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga
    let chapter: AidokuRunner.Chapter

    @Environment(\.dismiss) private var dismiss

    @State private var pages: [AidokuRunner.Page] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(chapter.formattedTitle())
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !pages.isEmpty {
                    Text("\(currentPage + 1) / \(pages.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Content
            if isLoading {
                ProgressView("Loading pages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadPages() }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            MacImageView(
                                source: source,
                                imageUrl: page.imageURL ?? "",
                                contentMode: .fit
                            )
                            .frame(maxWidth: .infinity)
                            .onAppear { currentPage = index }
                        }
                    }
                }
            }
        }
        .frame(width: 800, height: 720)
        .task {
            await loadPages()
        }
    }

    private func loadPages() async {
        isLoading = true
        loadError = nil
        do {
            pages = try await source.getPageList(manga: manga, chapter: chapter)
        } catch {
            loadError = error
        }
        isLoading = false
    }
}
