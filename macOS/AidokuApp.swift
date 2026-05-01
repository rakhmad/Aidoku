//
//  AidokuApp.swift
//  Aidoku (macOS)
//

import Nuke
import SwiftUI

@main
struct AidokuApp: App {
    init() {
        let pipeline = ImagePipeline {
            let dataCache = try? DataCache(name: "app.aidoku.Aidoku.datacache")
            let imageCache = Nuke.ImageCache()
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataCachePolicy = .storeOriginalData
            $0.isStoringPreviewsInMemoryCache = false
        }
        ImagePipeline.shared = pipeline
        _ = CoreDataManager.shared
        _ = SourceManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}
