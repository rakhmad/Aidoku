//
//  DownloadsView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import SwiftUI

struct DownloadsView: View {
    @State private var items: [DownloadedMangaInfo] = []
    @State private var isLoading = true
    @State private var showRemoveAllConfirm = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading Downloads…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Downloaded chapters will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                downloadList
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Remove All", role: .destructive) {
                        showRemoveAllConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Remove All Downloads?",
            isPresented: $showRemoveAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                Task {
                    await DownloadManager.shared.deleteAll()
                    await loadItems()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all downloaded chapters and cannot be undone.")
        }
        .task { await loadItems() }
        .onReceive(NotificationCenter.default.publisher(for: .downloadFinished)) { _ in
            Task { await loadItems() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadRemoved)) { _ in
            Task { await loadItems() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadsRemoved)) { _ in
            Task { await loadItems() }
        }
    }

    private var downloadList: some View {
        List(items) { item in
            DownloadedMangaRow(item: item) {
                Task {
                    await DownloadManager.shared.deleteChapters(for: item.mangaIdentifier)
                    await loadItems()
                }
            }
        }
    }

    private func loadItems() async {
        isLoading = true
        items = await DownloadManager.shared.getAllDownloadedManga()
        isLoading = false
    }
}

// MARK: - Row

private struct DownloadedMangaRow: View {
    let item: DownloadedMangaInfo
    let onDelete: () -> Void

    private var source: AidokuRunner.Source? {
        SourceManager.shared.source(for: item.sourceId)
    }

    var body: some View {
        HStack(spacing: 12) {
            coverImage
                .frame(width: 44, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text("\(item.chapterCount) chapter\(item.chapterCount == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(item.formattedSize)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Downloads", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let src = source, let url = item.coverUrl {
            MacImageView(source: src, imageUrl: url, contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
