//
//  ImportSheet.swift
//  CraveCircle (AICookBook)
//
//  The paste sheet — where a reel link becomes a recipe. Fusion: editorial header,
//  a clean paste field, one lime primary action. Validates the link client-side.
//

import SwiftUI
import UIKit
import PhotosUI

enum ReelURL {
    /// Accepts Instagram reels/posts, TikTok, and YouTube Shorts links.
    static func isValid(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard s.contains(".") else { return false }
        let hosts = ["instagram.com/reel", "instagram.com/reels", "instagram.com/p/",
                     "tiktok.com/", "vm.tiktok.com/", "youtube.com/shorts", "youtu.be/"]
        return hosts.contains { s.contains($0) }
    }
}

struct ImportSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showing: Bool

    @State private var url = ""
    @State private var showInvalid = false
    @State private var pickedVideo: PhotosPickerItem?
    @AppStorage(LanguagePrefs.key) private var langCode = LanguagePrefs.default.rawValue

    private var canSubmit: Bool { ReelURL.isValid(url) }
    private var language: AppLanguage { AppLanguage(rawValue: langCode) ?? LanguagePrefs.default }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What's cooking?")
                    .font(AppFont.display(28, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Pick a cooking video — CraveCircle builds the recipe right on your phone.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // PRIMARY — on-device import (no server, no sign-in)
            PhotosPicker(selection: $pickedVideo, matching: .videos) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.magnifyingglass").font(.system(size: 16, weight: .bold))
                    Text("Pick a cooking video").font(AppFont.body(16, weight: .bold))
                }
                .foregroundStyle(AppTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppTheme.accent, in: Capsule())
            }
            Text("Runs on your phone — no sign-in needed.")
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Rectangle().fill(AppTheme.separator).frame(height: 1)
                Text("or paste a link").font(AppFont.body(12)).foregroundStyle(AppTheme.textTertiary)
                Rectangle().fill(AppTheme.separator).frame(height: 1)
            }
            .padding(.top, 4)

            // SECONDARY — link import (needs the backend + sign-in, currently offline)
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("instagram.com/reel/…", text: $url)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .onChange(of: url) { _, _ in showInvalid = false }
                if !url.isEmpty {
                    Button {
                        url = ""; Haptics.tap()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear text")
                } else {
                    Button("Paste") { paste() }
                        .font(AppFont.body(15, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(showInvalid ? AppTheme.destructive : AppTheme.hairline, lineWidth: 1)
            )

            if showInvalid {
                Label("That doesn't look like a reel link.", systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.destructive)
            }

            PillButton(title: "Let's Cook", systemImage: "sparkles", kind: .outlined, fullWidth: true) {
                submit()
            }
            .opacity(canSubmit ? 1 : 0.45)
            .disabled(!canSubmit)

            Text("Link import needs sign-in — coming back soon.")
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background)
        .onChange(of: pickedVideo) { _, item in
            Task {
                if let file = try? await item?.loadTransferable(type: VideoFile.self) {
                    showing = false
                    await environment.importFromVideo(file.url)
                }
            }
        }
    }

    private func paste() {
        if let s = UIPasteboard.general.string {
            url = s.trimmingCharacters(in: .whitespacesAndNewlines)
            Haptics.tap()
        }
    }

    private func submit() {
        guard canSubmit else {
            showInvalid = true
            Haptics.toggle(false)
            return
        }
        Haptics.success()
        let link = url
        showing = false
        Task { await environment.startImport(from: link) }
    }
}
