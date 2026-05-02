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
| `macOS/Views/ContentView.swift` | Created | `NavigationSplitView` root — sidebar with Library + Sources |
| `macOS/Views/SourceSidebarView.swift` | Created | Lists installed sources, `+` button to add |
| `macOS/Views/AddSourceListSheet.swift` | Created | Paste URL → fetch source list → install sources |
| `macOS/Views/SourceBrowseView.swift` | Created | Paginated manga grid with listing tabs |
| `macOS/Views/MangaDetailView.swift` | Created | Cover + synopsis + chapter list + subscribe button |
| `macOS/Views/WebtoonReaderView.swift` | Created | Vertical scroll reader (`LazyVStack` of `MacImageView`) |
| `macOS/Views/MacLibraryView.swift` | ✅ **Created** | Grid of subscribed manga with CoreData integration |
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

## Build Fix Notes (May 1, 2026)

### Issue 1: Hashable Conformance
**Problem**: `AidokuRunner.Source` doesn't conform to `Hashable`, causing compilation errors in `SidebarSelection` enum.

**Solution**: Changed the enum to store source keys (String) instead of Source objects:
```swift
enum SidebarSelection: Hashable {
    case library
    case source(String)  // Stores source.key, not Source object
}
```

### Issue 2: Type Name Collision
**Problem**: `LibraryView` already exists in the iOS target, causing "invalid redeclaration" error.

**Solution**: Renamed the macOS library view to `MacLibraryView`:
- File: `macOS/Views/MacLibraryView.swift` (distinct from iOS `LibraryView.swift`)
- Struct name: `MacLibraryView` instead of `LibraryView`
- Updated `ContentView.swift` to use `MacLibraryView()`

## What Was Completed (Latest Session - May 1, 2026)

### 1. ✅ Library View Implementation
`macOS/Views/LibraryView.swift` has been fully implemented with:
- Grid layout using `LazyVGrid` matching `SourceBrowseView` style
- Loads library manga from CoreData via `CoreDataManager.shared.getLibraryManga()`
- Displays manga covers using `MacImageView` with proper source integration
- Tapping a cover opens `MangaDetailView` in a sheet
- Listens to `updateSourceList` and `addToLibrary` notifications for auto-refresh
- Shows empty state with `ContentUnavailableView` when library is empty
- Sorted by most recently added

### 2. ✅ ContentView Integration
`ContentView.swift` updated to include library:
- Implemented Option B: Two-section sidebar with Library + Sources
- New `SidebarSelection` enum to handle both library and source selections
- Library section appears first in the sidebar
- Sources section follows with existing source list
- Right-click context menu on sources to remove them
- Selecting library shows `LibraryView`, selecting source shows `SourceBrowseView`
- Default selection is Library

### 3. ✅ Fixed Manga Grid Layout
`SourceBrowseView.swift` `MangaCoverItem` updated:
- Changed from `aspectRatio(2/3)` to fixed `frame(height: 200)` for consistent alignment
- Increased spacing from 5 to 8 points between image and title
- Added `.padding(.bottom, 4)` to text for extra bottom padding
- Added `.clipped()` to prevent image overflow

### 4. ✅ Remove Source Context Menu
Implemented in the new `CombinedSidebarView`:
- Right-click context menu on each source row
- "Remove Source" button with destructive role
- Automatically updates source list after removal
- Returns to Library view if the removed source was selected

## What Still Needs to Be Done

All major features have been implemented! The app now has:
- ✅ Source management (add, browse, remove)
- ✅ Manga browsing with pagination
- ✅ Manga details view
- ✅ Library management
- ✅ Webtoon reader
- ✅ Integrated navigation

### Optional Future Enhancements:
- Add sorting/filtering options to Library view
- Add category support in Library view
- Add search functionality
- Add recently read/continue reading section
- Add download management for offline reading

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
