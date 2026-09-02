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
    @State private var localeID = "en-US"
    @State private var running = false
    @State private var result: OnDeviceTranscriber.Output?
    @State private var errorText: String?

    private let locales = [
        ("English (US)", "en-US"), ("English (India)", "en-IN"),
        ("Hindi", "hi-IN"), ("Spanish", "es-ES"), ("French", "fr-FR")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("1 · Pick a cooking video") {
                    PhotosPicker(selection: $pickedItem, matching: .videos) {
                        Label(videoURL == nil ? "Choose video" : "Video selected ✓", systemImage: "video.fill")
                    }
                }
                Section("2 · Language (best guess)") {
                    Picker("Language", selection: $localeID) {
                        ForEach(locales, id: \.1) { Text($0.0).tag($0.1) }
                    }
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
