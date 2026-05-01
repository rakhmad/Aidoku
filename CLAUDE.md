# Aidoku macOS Manhwa Reader — Session Context

## Branch
`claude/elegant-mendel-0bf142` (worktree: `/Users/razhari/tmp/Aidoku/.claude/worktrees/elegant-mendel-0bf142`)

## What Was Built
A full macOS manhwa reader feature on top of the existing Aidoku iOS codebase. The macOS target already existed as a stub — this session implemented it end-to-end.

## Completed Commits (newest first)
```
78808e1 fix(macOS): source switching, chapter names, and add library subscribe button
b34af24 fix(macOS): bump deployment target to 13.0 for defaultSize API
69494d8 fix(macOS): link NukeUI framework to macOS target
a30fa2e feat(macOS): register all new macOS views in Xcode target compile sources
a1a1bd5 feat(macOS): add vertical scroll webtoon reader
ebe0748 feat(macOS): add manga detail view with cover, synopsis, and chapter list
329e1b1 feat(macOS): add source browse view with paginated manga grid
34d5ac9 feat(macOS): add source list fetching and one-click source install
708c0be feat(macOS): add NavigationSplitView shell and sources sidebar
9473241 feat(macOS): add MacImageView, platform-safe image loader for macOS
e1723be feat(macOS): initialize Nuke pipeline and warm singletons on launch
0ad86e9 feat(macOS): enable network entitlement and allow HTTP sources
```

## Files Created / Modified

| File | Status | Purpose |
|---|---|---|
| `macOS/macOS.entitlements` | Modified | Network + HTTP access for sandboxed app |
| `macOS/Info.plist` | Modified | `NSAllowsArbitraryLoads` for HTTP sources |
| `macOS/AidokuApp.swift` | Modified | Nuke pipeline + CoreData/SourceManager init |
| `macOS/Views/MacImageView.swift` | Created | macOS-native Nuke image loader (no UIKit) |
| `macOS/Views/ContentView.swift` | Created | `NavigationSplitView` root — sidebar + detail |
| `macOS/Views/SourceSidebarView.swift` | Created | Lists installed sources, `+` button to add |
| `macOS/Views/AddSourceListSheet.swift` | Created | Paste URL → fetch source list → install sources |
| `macOS/Views/SourceBrowseView.swift` | Created | Paginated manga grid with listing tabs |
| `macOS/Views/MangaDetailView.swift` | Created | Cover + synopsis + chapter list + subscribe button |
| `macOS/Views/WebtoonReaderView.swift` | Created | Vertical scroll reader (`LazyVStack` of `MacImageView`) |
| `macOS/Views/LibraryView.swift` | **Stub — not implemented** | Still just `Spacer()` |
| `Aidoku.xcodeproj/project.pbxproj` | Modified | All new files registered in macOS target |

## Key API Reference

```swift
// Source management
SourceManager.shared.sources                          // [AidokuRunner.Source]
SourceManager.shared.addSourceList(url:)              // async -> Bool
SourceManager.shared.importSource(from:)              // async -> AidokuRunner.Source?
SourceManager.shared.source(for:)                     // AidokuRunner.Source?
SourceManager.shared.remove(source:)                  // removes source + files + CoreData
SourceManager.shared.hasSourceInstalled(id:)          // Bool

// Browsing
source.listings                                       // [AidokuRunner.Listing]
source.getMangaList(listing:page:)                    // async throws -> MangaPageResult
source.getMangaList(filters:page:)                    // async throws -> MangaPageResult
source.getMangaUpdate(manga:needsDetails:needsChapters:) // async throws -> AidokuRunner.Manga
source.getPageList(manga:chapter:)                    // async throws -> [AidokuRunner.Page]
source.getModifiedImageRequest(url:context:)          // async -> URLRequest

// Manga model
manga.key, manga.sourceKey, manga.title
manga.cover        // String? (URL)
manga.description  // String?
manga.authors      // [String]?
manga.chapters     // [AidokuRunner.Chapter]? (after getMangaUpdate)

// Chapter model
chapter.key, chapter.formattedTitle(), chapter.formattedSubtitle(page:sourceKey:)

// Page model
page.imageURL      // String?

// Library
MangaManager.shared.addToLibrary(sourceId:manga:chapters:fetchMangaDetails:)  // async
MangaManager.shared.removeFromLibrary(sourceId:mangaId:)                      // async
CoreDataManager.shared.hasLibraryManga(sourceId:mangaId:)                     // Bool
CoreDataManager.shared.getLibraryManga(category:)                             // [LibraryMangaObject]
```

## What Still Needs to Be Done

### 1. Remove Source from Sidebar
In `macOS/Views/SourceSidebarView.swift`, add a right-click context menu to each row:
```swift
.contextMenu {
    Button("Remove Source", role: .destructive) {
        SourceManager.shared.remove(source: source)
        sources = SourceManager.shared.sources
        if selectedSource?.key == source.key { selectedSource = nil }
    }
}
```

### 2. Library View
`macOS/Views/LibraryView.swift` is still a stub (`Spacer()`). Replace it with a grid of subscribed manga.

The library is accessible via:
```swift
let libraryItems = CoreDataManager.shared.getLibraryManga()  // [LibraryMangaObject]
// Each LibraryMangaObject has .manga (MangaObject) → .toNewManga() → AidokuRunner.Manga
// .manga.sourceId gives you the source key to look up via SourceManager.shared.source(for:)
```

The `LibraryView` needs to:
1. Load all library manga on appear
2. Show them in a `LazyVGrid` like `SourceBrowseView`
3. Tapping a cover opens `MangaDetailView(source:manga:)` as a sheet
4. Refresh on `.updateSourceList` or `.addToLibrary` notifications

### 3. Plug LibraryView into ContentView
`ContentView.swift` currently only shows the source browser. Add a library tab or top-level toggle so the user can switch between "Sources" and "Library".

Option A — Tab bar style with `TabView`:
```swift
TabView {
    LibraryView().tabItem { Label("Library", systemImage: "books.vertical") }
    NavigationSplitView { ... }.tabItem { Label("Sources", systemImage: "square.grid.2x2") }
}
```

Option B — Two-section sidebar: add a "Library" section above the sources list.

### 4. Fix Manga Grid Layout (SourceBrowseView)
In `macOS/Views/SourceBrowseView.swift`, the `MangaCoverItem` private struct needs:
- Fixed cover height (not just aspect ratio) so all covers align
- More spacing between the image and title
- More padding below the title

Suggested fix in `MangaCoverItem`:
```swift
VStack(alignment: .leading, spacing: 8) {  // was spacing: 5
    MacImageView(...)
        .frame(height: 200)                 // fixed height instead of aspectRatio
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6))

    Text(manga.title)
        .font(.system(size: 12))
        .lineLimit(2)
        .foregroundStyle(.primary)
        .padding(.bottom, 4)               // extra bottom padding
}
```

## Build Instructions

```bash
cd /Users/razhari/tmp/Aidoku/.claude/worktrees/elegant-mendel-0bf142

# Build
xcodebuild -scheme "Aidoku (macOS)" -destination "platform=macOS" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

# Run the built app
open "/Users/razhari/Library/Developer/Xcode/DerivedData/Aidoku-flhuyyfzwkdfwnekiiscxpuojraj/Build/Products/Debug/Aidoku.app"
```

Or open in Xcode:
```bash
open Aidoku.xcodeproj
# Select scheme: Aidoku (macOS) → My Mac → ⌘R
```

## Architecture Notes

- **No UIKit in macOS files** — `SourceImageView`, `MangaGridItem` etc. are iOS-only. Use `MacImageView` for all image loading.
- **Localization** — `NSLocalizedString` keys like `"CHAPTER_X"` require `Localizable.strings` to be in the macOS Resources build phase (already fixed).
- **`.id(source.key)` on SourceBrowseView** — required to force SwiftUI to recreate the view when source changes, otherwise the grid doesn't refresh.
- **Source install URL that works**: `https://aidoku-community.github.io/sources/index.min.json`
