//
//  MacImageView.swift
//  Aidoku (macOS)
//

import AidokuRunner
import NukeUI
import SwiftUI

struct MacImageView: View {
    var source: AidokuRunner.Source?
    let imageUrl: String
    var contentMode: ContentMode = .fill

    @State private var imageRequest: ImageRequest?

    var body: some View {
        LazyImage(request: imageRequest) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if state.error != nil {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
            }
        }
        .onAppear {
            guard imageRequest == nil, !imageUrl.isEmpty else { return }
            Task { await loadRequest() }
        }
        .onChange(of: imageUrl) { _ in
            imageRequest = nil
            Task { await loadRequest() }
        }
    }

    private func loadRequest() async {
        guard let url = URL(string: imageUrl) else { return }
        if let source {
            let request = await source.getModifiedImageRequest(url: url, context: nil)
            imageRequest = ImageRequest(urlRequest: request)
        } else {
            imageRequest = ImageRequest(url: url)
        }
    }
}
