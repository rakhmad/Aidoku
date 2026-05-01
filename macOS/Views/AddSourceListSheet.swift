//
//  AddSourceListSheet.swift
//  Aidoku (macOS)
//

import SwiftUI

struct AddSourceListSheet: View {
    var onInstalled: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var sourceList: SourceList?
    @State private var isLoadingList = false
    @State private var errorMessage: String?
    @State private var installing: Set<String> = []
    @State private var justInstalled: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Add Source List")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // URL input row
            HStack(spacing: 8) {
                TextField("Paste source list URL here…", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { fetchList() }
                Button("Fetch") { fetchList() }
                    .disabled(urlText.isEmpty || isLoadingList)
            }
            .padding()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            if isLoadingList {
                ProgressView("Loading source list…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let sourceList {
                HStack {
                    Text(sourceList.name)
                        .font(.headline)
                    Text("(\(sourceList.sources.count) sources)")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                List(sourceList.sources, id: \.id) { externalInfo in
                    sourceRow(externalInfo)
                }
            } else {
                Text("Enter a source list URL and press Fetch.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                Spacer()
            }
        }
        .frame(width: 480, height: 540)
    }

    @ViewBuilder
    private func sourceRow(_ externalInfo: ExternalSourceInfo) -> some View {
        let info = externalInfo.toInfo()
        let isInstalled = justInstalled.contains(info.sourceId)
            || SourceManager.shared.hasSourceInstalled(id: info.sourceId)
        let isInstalling = installing.contains(info.sourceId)
        let canInstall = externalInfo.fileURL != nil

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(info.name)
                        .font(.system(size: 14, weight: .medium))
                    Text("v\(info.version)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(info.languages.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isInstalled {
                Text("Installed")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if isInstalling {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 60)
            } else {
                Button("Get") {
                    Task { await install(externalInfo) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canInstall)
            }
        }
    }

    private func fetchList() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Invalid URL — check that it starts with https://"
            return
        }
        errorMessage = nil
        isLoadingList = true
        Task {
            let success = await SourceManager.shared.addSourceList(url: url)
            isLoadingList = false
            if success || SourceManager.shared.sourceLists.contains(where: { $0.url == url }) {
                sourceList = SourceManager.shared.sourceLists.first { $0.url == url }
                errorMessage = nil
            } else {
                errorMessage = "Could not load a source list from that URL. Check it points to a valid JSON list."
            }
        }
    }

    private func install(_ externalInfo: ExternalSourceInfo) async {
        guard let fileURL = externalInfo.fileURL else { return }
        installing.insert(externalInfo.id)
        let source = await SourceManager.shared.importSource(from: fileURL)
        installing.remove(externalInfo.id)
        if source != nil {
            justInstalled.insert(externalInfo.id)
            onInstalled()
        }
    }
}
