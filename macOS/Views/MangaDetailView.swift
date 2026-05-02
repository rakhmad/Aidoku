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

    @State private var readerPresentation: ReaderPresentation?
    @State private var isInLibrary = false
    @State private var isSubscribing = false

    // [chapterId: (page, timestamp)] — page == -1 means completed
    @State private var readingHistory: [String: (page: Int, date: Int)] = [:]

    // [chapterId: status] — tracks download state per chapter
    @State private var chapterDownloadStatus: [String: DownloadStatus] = [:]
    // [chapterId: (completed, total)] — live progress for active downloads
    @State private var downloadProgress: [String: (Int, Int)] = [:]

    var displayManga: AidokuRunner.Manga { detailedManga ?? manga }

    // The chapter + page to resume from (most recently read, by timestamp)
    private var resumeTarget: (chapter: AidokuRunner.Chapter, page: Int)? {
        guard !chapters.isEmpty, !readingHistory.isEmpty else { return nil }
        let candidates = readingHistory.compactMap { (chapterId, info) -> (AidokuRunner.Chapter, Int, Int)? in
            guard let ch = chapters.first(where: { $0.key == chapterId }) else { return nil }
            return (ch, info.page, info.date)
        }
        guard let latest = candidates.max(by: { $0.2 < $1.2 }) else { return nil }
        let (chapter, page, _) = latest

        if page == -1 {
            // Chapter completed — advance to the next unread chapter in reading order.
            guard let idx = chapters.firstIndex(where: { $0.key == chapter.key }) else { return nil }
            let nextIdx = isNewestFirst ? idx - 1 : idx + 1
            guard nextIdx >= 0, nextIdx < chapters.count else { return (chapter, 0) }
            let nextChapter = chapters[nextIdx]
            let nextPage = readingHistory[nextChapter.key].map { $0.page == -1 ? 0 : $0.page } ?? 0
            return (nextChapter, nextPage)
        } else {
            return (chapter, page)
        }
    }

    // Detect sort direction: true if chapters[0] has a higher number than chapters[1]
    private var isNewestFirst: Bool {
        guard chapters.count >= 2,
              let n0 = chapters[0].chapterNumber,
              let n1 = chapters[1].chapterNumber else { return true }
        return n0 > n1
    }

    // First chapter to read depends on sort direction
    private var firstChapterIndex: Int { isNewestFirst ? chapters.count - 1 : 0 }

    private struct ReaderPresentation: Identifiable {
        let id = UUID()
        let startIndex: Int
        let initialPage: Int
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left panel: scrollable cover + metadata, with pinned action buttons
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 10) {
                        MacImageView(
                            source: source,
                            imageUrl: displayManga.cover ?? "",
                            contentMode: .fill
                        )
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(displayManga.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        if let authors = displayManga.authors, !authors.isEmpty {
                            Text(authors.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding([.horizontal, .top])
                    .padding(.bottom, 8)
                }

                Divider()

                // Pinned buttons — always visible regardless of image/title size
                VStack(spacing: 8) {
                    Button {
                        if let target = resumeTarget,
                           let idx = chapters.firstIndex(where: { $0.key == target.chapter.key }) {
                            readerPresentation = ReaderPresentation(startIndex: idx, initialPage: target.page)
                        } else {
                            readerPresentation = ReaderPresentation(startIndex: firstChapterIndex, initialPage: 0)
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity, minHeight: 28)
                        } else {
                            Label(
                                resumeTarget != nil ? "Resume Reading" : "Start Reading",
                                systemImage: resumeTarget != nil ? "arrow.clockwise.circle.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || chapters.isEmpty)

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
                    .buttonStyle(.bordered)
                    .tint(isInLibrary ? .secondary : .accentColor)
                    .disabled(isSubscribing)
                }
                .padding()
            }
            .frame(width: 190)

            Divider()

            // Right panel: synopsis + chapters
            VStack(alignment: .leading, spacing: 0) {
                if let desc = displayManga.description, !desc.isEmpty {
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .padding()
                    Divider()
                }

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
                            let idx = chapters.firstIndex(where: { $0.key == chapter.key }) ?? 0
                            readerPresentation = ReaderPresentation(startIndex: idx, initialPage: savedPage(for: chapter))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chapter.formattedTitle())
                                        .font(.system(size: 14))
                                        .foregroundStyle(isRead(chapter) ? .secondary : .primary)
                                    if let subtitle = chapter.formattedSubtitle(
                                        page: nil,
                                        sourceKey: source.key
                                    ) {
                                        Text(subtitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                chapterDownloadIcon(for: chapter)
                                chapterStatusIcon(for: chapter)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            let dlStatus = chapterDownloadStatus[chapter.key] ?? .none
                            if dlStatus == .finished {
                                Button(role: .destructive) {
                                    Task { await deleteDownload(chapter) }
                                } label: {
                                    Label("Delete Download", systemImage: "trash")
                                }
                            } else if dlStatus == .queued || dlStatus == .downloading {
                                Button {
                                    let id = ChapterIdentifier(
                                        sourceKey: source.key, mangaKey: manga.key,
                                        chapterKey: chapter.key)
                                    Task { await DownloadManager.shared.cancelDownload(for: id) }
                                } label: {
                                    Label("Cancel Download", systemImage: "xmark.circle")
                                }
                            } else {
                                Button {
                                    Task { await downloadChapter(chapter) }
                                } label: {
                                    Label("Download Chapter", systemImage: "arrow.down.circle")
                                }
                            }
                            if isRead(chapter) {
                                Divider()
                                Button {
                                    Task { await markUnread(chapter) }
                                } label: {
                                    Label("Mark as Unread", systemImage: "minus.circle")
                                }
                            }
                        }
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
        .sheet(item: $readerPresentation) { presentation in
            if !chapters.isEmpty {
                WebtoonReaderView(
                    source: source,
                    manga: displayManga,
                    chapters: chapters,
                    isNewestFirst: isNewestFirst,
                    startIndex: presentation.startIndex,
                    initialPage: presentation.initialPage
                )
            }
        }
        .onChange(of: readerPresentation == nil) { _, isNil in
            guard isNil else { return }
            Task {
                readingHistory = await CoreDataManager.shared.getReadingHistory(
                    sourceId: source.key,
                    mangaId: manga.key
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
        .onReceive(NotificationCenter.default.publisher(for: .downloadsQueued)) { note in
            guard let downloads = note.object as? [Download] else { return }
            for d in downloads where d.chapterIdentifier.mangaKey == manga.key {
                chapterDownloadStatus[d.chapterIdentifier.chapterKey] = .queued
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadProgressed)) { note in
            guard let d = note.object as? Download,
                  d.chapterIdentifier.mangaKey == manga.key else { return }
            chapterDownloadStatus[d.chapterIdentifier.chapterKey] = .downloading
            downloadProgress[d.chapterIdentifier.chapterKey] = (d.progress, d.total)
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadFinished)) { note in
            guard let d = note.object as? Download,
                  d.chapterIdentifier.mangaKey == manga.key else { return }
            chapterDownloadStatus[d.chapterIdentifier.chapterKey] = .finished
            downloadProgress.removeValue(forKey: d.chapterIdentifier.chapterKey)
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadRemoved)) { note in
            guard let id = note.object as? ChapterIdentifier,
                  id.mangaKey == manga.key else { return }
            chapterDownloadStatus[id.chapterKey] = .none
            downloadProgress.removeValue(forKey: id.chapterKey)
        }
    }

    // MARK: - Chapter status helpers

    private func isCompleted(_ chapter: AidokuRunner.Chapter) -> Bool {
        readingHistory[chapter.key]?.page == -1
    }

    private func isRead(_ chapter: AidokuRunner.Chapter) -> Bool {
        readingHistory[chapter.key] != nil
    }

    private func savedPage(for chapter: AidokuRunner.Chapter) -> Int {
        guard let info = readingHistory[chapter.key], info.page != -1 else { return 0 }
        return info.page
    }

    @ViewBuilder
    private func chapterStatusIcon(for chapter: AidokuRunner.Chapter) -> some View {
        if isCompleted(chapter) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        } else if let info = readingHistory[chapter.key] {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(Color.accentColor)
                .help("Page \(info.page + 1)")
        } else {
            Image(systemName: "play.circle")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func chapterDownloadIcon(for chapter: AidokuRunner.Chapter) -> some View {
        let status = chapterDownloadStatus[chapter.key] ?? .none
        switch status {
        case .finished:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.secondary)
                .help("Downloaded")
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .help("Queued")
        case .downloading:
            let prog = downloadProgress[chapter.key]
            DownloadingIcon(label: prog.map { "Downloading \($0.0)/\($0.1)" } ?? "Downloading…")
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
                .help("Download failed")
        default:
            EmptyView()
        }
    }

    // MARK: - Actions

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

    private func downloadChapter(_ chapter: AidokuRunner.Chapter) async {
        chapterDownloadStatus[chapter.key] = .queued
        await DownloadManager.shared.download(manga: displayManga, chapters: [chapter])
    }

    private func deleteDownload(_ chapter: AidokuRunner.Chapter) async {
        let id = ChapterIdentifier(sourceKey: source.key, mangaKey: manga.key, chapterKey: chapter.key)
        await DownloadManager.shared.delete(chapters: [id])
    }

    private func markUnread(_ chapter: AidokuRunner.Chapter) async {
        await HistoryManager.shared.removeHistory(
            sourceId: source.key,
            mangaId: manga.key,
            chapterIds: [chapter.key]
        )
        readingHistory = await CoreDataManager.shared.getReadingHistory(
            sourceId: source.key,
            mangaId: manga.key
        )
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
            readingHistory = await CoreDataManager.shared.getReadingHistory(
                sourceId: source.key,
                mangaId: manga.key
            )
            for chapter in chapters {
                let id = ChapterIdentifier(sourceKey: source.key, mangaKey: manga.key, chapterKey: chapter.key)
                chapterDownloadStatus[chapter.key] = DownloadManager.shared.getDownloadStatus(for: id)
            }
        } catch {
            loadError = error
        }
        isLoading = false
    }
}

// Pure-SwiftUI pulsing arrow — avoids NSProgressIndicator rendering issues in List rows
private struct DownloadingIcon: View {
    let label: String
    @State private var pulsing = false

    var body: some View {
        Image(systemName: "arrow.down.circle")
            .foregroundStyle(Color.accentColor)
            .opacity(pulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .help(label)
    }
}
