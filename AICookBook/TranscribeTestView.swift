//
//  TranscribeTestView.swift
//  CraveCircle (AICookBook)
//
//  Beta tester for on-device transcription. Pick a cooking video → the phone extracts the
//  audio and transcribes it with SpeechTranscriber (no server), and reports how long it took.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct TranscribeTestView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var localeID = AppLanguage.preferred.localeID   // defaults to your selected language
    @State private var running = false
    @State private var result: OnDeviceTranscriber.Output?
    @State private var errorText: String?

    // Populated at runtime with EVERY language this device can transcribe on-device.
    @State private var localeOptions: [(name: String, id: String)] = []

    private let fallbackLocales: [(name: String, id: String)] = [
        ("English (US)", "en-US"), ("Hindi", "hi-IN"), ("Marathi", "mr-IN"),
        ("Tamil", "ta-IN"), ("Telugu", "te-IN"), ("Bengali", "bn-IN"),
        ("Spanish", "es-ES"), ("French", "fr-FR")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("1 · Pick a cooking video") {
                    PhotosPicker(selection: $pickedItem, matching: .videos) {
                        Label(videoURL == nil ? "Choose video" : "Video selected ✓", systemImage: "video.fill")
                    }
                }
                Section {
                    Picker("Language", selection: $localeID) {
                        ForEach(localeOptions.isEmpty ? fallbackLocales : localeOptions, id: \.id) {
                            Text($0.name).tag($0.id)
                        }
                    }
                } header: {
                    Text("2 · Language")
                } footer: {
                    Text("Pick the video's spoken language — the model downloads automatically the first time. Defaults to your preferred language from Settings.")
                }
                Section {
                    Button {
                        Task { await run() }
                    } label: {
                        HStack(spacing: 8) {
                            if running { ProgressView() }
                            Text(running ? "Transcribing on device…" : "Transcribe on device")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(videoURL == nil || running)
                }

                if let result {
                    Section("Transcript · \(String(format: "%.1f", result.seconds))s on device · \(result.localeID)") {
                        Text(result.text.isEmpty ? "(no speech detected)" : result.text)
                            .font(.callout)
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(AppTheme.destructive).font(.footnote) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("On-device transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .tint(AppTheme.accentInk)
            .onChange(of: pickedItem) { _, item in
                Task {
                    if let file = try? await item?.loadTransferable(type: VideoFile.self) {
                        videoURL = file.url; result = nil; errorText = nil
                    }
                }
            }
            .task { await loadLocales() }
        }
    }

    /// Offer every language this device can transcribe on-device, named in the user's language.
    private func loadLocales() async {
        let ids = await OnDeviceTranscriber.supportedLocaleIDs()
        guard !ids.isEmpty else { return }   // keep the fallback list
        let display = Locale.current
        let opts = ids.map { id in
            (name: display.localizedString(forIdentifier: id) ?? id, id: id)
        }.sorted { $0.name < $1.name }
        localeOptions = opts
        if !opts.contains(where: { $0.id == localeID }) {   // keep selection valid
            localeID = opts.first(where: { $0.id.hasPrefix(AppLanguage.preferred.rawValue) })?.id
                ?? opts.first?.id ?? localeID
        }
    }

    private func run() async {
        running = true; errorText = nil; result = nil
        defer { running = false }
        guard await OnDeviceTranscriber.ensureAuthorized() else {
            errorText = "Speech recognition permission was denied — enable it in Settings."
            return
        }
        guard let videoURL else { return }
        do {
            try await OnDeviceTranscriber.installAssetIfNeeded(localeID: localeID)
            result = try await OnDeviceTranscriber.transcribe(url: videoURL, localeID: localeID)
        } catch {
            errorText = "Couldn't transcribe: \(error)"
        }
    }
}

/// Copies a picked video into a temp file we can read.
struct VideoFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFile(url: copy)
        }
    }
}
