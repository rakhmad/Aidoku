//
//  WebtoonReaderView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import Nuke
import SwiftUI

struct WebtoonReaderView: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga
    let chapters: [AidokuRunner.Chapter]
    var isNewestFirst: Bool = true
    var startIndex: Int = 0
    var initialPage: Int = 0

    @Environment(\.dismiss) private var dismiss

    @State private var activeIndex: Int
    @State private var pages: [AidokuRunner.Page] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var currentPage = 0
    @State private var sessionStartDate = Date()
    @State private var sessionReadPages: Set<Int> = []
    @State private var isLoadingNext = false

    init(
        source: AidokuRunner.Source,
        manga: AidokuRunner.Manga,
        chapters: [AidokuRunner.Chapter],
        isNewestFirst: Bool = true,
        startIndex: Int = 0,
        initialPage: Int = 0
    ) {
        self.source = source
        self.manga = manga
        self.chapters = chapters
        self.isNewestFirst = isNewestFirst
        self.startIndex = startIndex
        self.initialPage = initialPage
        self._activeIndex = State(initialValue: startIndex)
    }

    private var currentChapter: AidokuRunner.Chapter { chapters[activeIndex] }
    private var nextIndex: Int? {
        if isNewestFirst {
            return activeIndex > 0 ? activeIndex - 1 : nil
        } else {
            return activeIndex < chapters.count - 1 ? activeIndex + 1 : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(width: 800, height: 720)
        .task(id: activeIndex) { await loadPages() }
        .onDisappear { Task { await endSession() } }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 1) {
                Text(currentChapter.formattedTitle())
                    .font(.headline)
                    .lineLimit(1)
                if !pages.isEmpty {
                    Text("\(currentPage + 1) / \(pages.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            if let next = nextIndex {
                Button {
                    Task { await advanceToChapter(next) }
                } label: {
                    Label("Next Chapter", systemImage: "forward.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Next Chapter: \(chapters[next].formattedTitle())")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading \(currentChapter.formattedTitle())…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await loadPages() } }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            reader
        }
    }

    // MARK: - Reader

    private var reader: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        MacImageView(
                            source: source,
                            imageUrl: extractURL(page),
                            contentMode: .fit
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .id(index)
                        // Zero callbacks inside items — any state mutation here
                        // creates a circular dependency in LazySubviewPlacements
                        // that loops at 100% CPU (confirmed in sample traces).
                    }
                    chapterEndBanner
                }
            }
            // onScrollGeometryChange is READ-ONLY: it observes contentOffset but
            // never writes back to the scroll view, so there is no oscillation.
            // scrollPosition(id:) is bidirectional — it caused 1200 layout cycles/s.
            .onScrollGeometryChange(for: Int.self) { geometry in
                // Map content offset to a page index estimate.
                let scrollable = geometry.contentSize.height - geometry.containerSize.height
                guard scrollable > 0, !pages.isEmpty else { return 0 }
                let progress = min(1, max(0, geometry.contentOffset.y / scrollable))
                return min(pages.count - 1, Int(progress * CGFloat(pages.count)))
            } action: { _, newPage in
                guard newPage != currentPage else { return }
                currentPage = newPage
                sessionReadPages.insert(newPage)
                if newPage == pages.count - 1 {
                    Task { await saveProgress(page: newPage) }
                }
            }
            // Detect when user has scrolled within 300 px of the bottom → advance chapter.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let remaining = geometry.contentSize.height
                    - geometry.contentOffset.y
                    - geometry.containerSize.height
                return remaining < 300 && geometry.contentSize.height > geometry.containerSize.height
            } action: { _, isNearBottom in
                guard isNearBottom, let next = nextIndex, !isLoadingNext else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    await advanceToChapter(next)
                }
            }
            // Recreate scroll view on chapter change (resets position to top)
            .id(activeIndex)
            .onAppear {
                guard initialPage > 0 && activeIndex == startIndex && !pages.isEmpty else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    proxy.scrollTo(min(initialPage, pages.count - 1), anchor: .top)
                }
            }
        }
    }

    // MARK: - Chapter-end banner

    @ViewBuilder
    private var chapterEndBanner: some View {
        if let next = nextIndex {
            VStack(spacing: 10) {
                Divider().padding(.horizontal, 40)
                if isLoadingNext {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading \(chapters[next].formattedTitle())…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 6) {
                        Text("End of \(currentChapter.formattedTitle())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Next: \(chapters[next].formattedTitle())")
                            .font(.headline)
                    }
                }
                Divider().padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 6) {
                Divider().padding(.horizontal, 40)
                Text("You're all caught up!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func extractURL(_ page: AidokuRunner.Page) -> String {
        if case .url(let url, _) = page.content { return url.absoluteString }
        return ""
    }

    // MARK: - Data loading

    private func loadPages() async {
        isLoading = true
        loadError = nil
        currentPage = 0
        sessionStartDate = Date()
        sessionReadPages = []
        do {
            pages = try await source.getPageList(manga: manga, chapter: currentChapter)
        } catch {
            loadError = error
        }
        isLoading = false
        guard loadError == nil else { return }
        await preloadImages(pages)
    }

    private func preloadImages(_ pages: [AidokuRunner.Page]) async {
        for page in pages {
            guard !Task.isCancelled else { return }
            guard case .url(let url, _) = page.content else { continue }
            let urlRequest = await source.getModifiedImageRequest(url: url, context: nil)
            guard !Task.isCancelled else { return }
            ImagePipeline.shared.loadImage(with: ImageRequest(urlRequest: urlRequest)) { _ in }
        }
    }

    private func advanceToChapter(_ index: Int) async {
        guard index >= 0, index < chapters.count, !isLoadingNext else { return }
        isLoadingNext = true
        await saveProgress(page: currentPage)
        await endSession()
        isLoadingNext = false
        activeIndex = index
    }

    // MARK: - Progress persistence

    private func saveProgress(page: Int) async {
        guard !pages.isEmpty else { return }
        let isCompleted = page == pages.count - 1
        let oldChapter = currentChapter.toOld(sourceId: source.key, mangaId: manga.key)
        await HistoryManager.shared.setProgress(
            chapter: oldChapter,
            progress: page,
            totalPages: pages.count,
            completed: isCompleted
        )
        if isCompleted {
            await HistoryManager.shared.addHistory(
                sourceId: source.key,
                mangaId: manga.key,
                chapters: [currentChapter]
            )
        }
    }

    private func endSession() async {
        // Persist current position so icons and resume reflect closing mid-chapter.
        await saveProgress(page: currentPage)
        guard !sessionReadPages.isEmpty else { return }
        let identifier = ChapterIdentifier(
            sourceKey: source.key,
            mangaKey: manga.key,
            chapterKey: currentChapter.key
        )
        let data = HistoryManager.ReadingSessionData(
            startDate: sessionStartDate,
            endDate: Date(),
            pagesRead: sessionReadPages.count
        )
        await HistoryManager.shared.addSession(chapterIdentifier: identifier, data: data)
    }
}
