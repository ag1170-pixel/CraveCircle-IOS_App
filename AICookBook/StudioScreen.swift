//
//  StudioScreen.swift
//  CraveCircle (AICookBook)
//
//  The creator's workspace. One primary CTA — "Publish new recipe" — opens a blank
//  editor via the existing `pendingNewRecipe` hook, so the recipe editor sheet handles
//  the actual authoring. Drafts and already-published recipes live in two tidy sections
//  so a creator can keep working on either without hunting through their library.
//
//  Reaches: environment.myDrafts, myPublished, publishDraft(recipeId:), unpublishRecipe(),
//  pendingNewRecipe, selectRecipe(_:).
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif
import UniformTypeIdentifiers

struct StudioScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var pickedVideo: PhotosPickerItem?
    @State private var isLoadingMedia = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                statsRow
                // The big "Write a new recipe" CTA used to live here but it duplicated the
                // "Write from scratch" tile below. One entry point per action — iOS native.
                shareTilesRow
                draftsSection
                publishedSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Studio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        // Studio opens as a full-screen cover from the + sheet. A cover doesn't give you a
        // back arrow for free — we add an explicit Close so the user is never trapped.
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                        Text("Close")
                            .font(AppFont.body(16, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accentInk)
                }
            }
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        // Followers tile was removed — the backend doesn't expose a real follower count yet, and
        // showing "0 Followers" to a creator with real followers lies to them. Put it back once
        // the server surfaces the number.
        HStack(spacing: AppSpacing.sm) {
            stat("Published", "\(environment.myPublished.count)")
            stat("Drafts",    "\(environment.myDrafts.count)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.serif(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Primary CTA

    /// Dismiss Studio FIRST, THEN flip pendingNewRecipe — otherwise the full-screen cover is
    /// still on top of MainTabView and the blank-editor sheet never presents. The small delay
    /// lets the dismiss animation finish before the editor pushes.
    private func openWriteFromScratch() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            environment.requestTabSwitch(.home)
            environment.pendingNewRecipe = true
        }
    }

    // MARK: Share tiles — photo + video

    private var shareTilesRow: some View {
        // Three tiles: Write from scratch (manual editor) · Share a photo (OCR) · Share a video
        // (transcribe). Flows into a vertical stack so each tile has room for a subtitle; a 3-col
        // grid on an iPhone 12 width makes the subtitles unreadable.
        VStack(spacing: AppSpacing.sm) {
            Button {
                Haptics.tap()
                openWriteFromScratch()
            } label: {
                shareTile(icon: "square.and.pencil", title: "Write from scratch",
                          subtitle: "Open a blank editor. Add your ingredients and directions yourself.")
            }
            .buttonStyle(.plain)

            #if !XTOOL_WSL
            PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 6, matching: .images) {
                shareTile(icon: "photo.on.rectangle", title: "Share a photo",
                          subtitle: "Pick up to 6 photos — we'll pull the ingredients and steps.")
            }
            .buttonStyle(.plain)
            .disabled(isLoadingMedia)

            PhotosPicker(selection: $pickedVideo, matching: .videos) {
                shareTile(icon: "video", title: "Share a video",
                          subtitle: "Pick a short cooking clip — we'll transcribe it.")
            }
            .buttonStyle(.plain)
            .disabled(isLoadingMedia)
            #else
            shareTile(icon: "photo.on.rectangle", title: "Share a photo",
                      subtitle: "Photo picker is unavailable on this build.")
            shareTile(icon: "video", title: "Share a video",
                      subtitle: "Video picker is unavailable on this build.")
            #endif
        }
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty, !isLoadingMedia else { return }
            Task { await handlePickedPhotos(items) }
        }
        .onChange(of: pickedVideo) { _, item in
            guard let item, !isLoadingMedia else { return }
            Task { await handlePickedVideo(item) }
        }
        .overlay {
            if isLoadingMedia {
                ProgressView().padding().background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    /// iOS-native action row: icon tile on the left, title + subtitle middle, chevron right.
    /// Reads at any width; scales down text instead of wrapping into stacked words.
    private func shareTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
                .frame(width: 40, height: 40)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    #if !XTOOL_WSL
    @MainActor
    private func handlePickedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingMedia = true
        defer { isLoadingMedia = false; pickedPhotos = [] }
        var images: [UIImage] = []
        for item in items.prefix(6) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                images.append(img)
            }
        }
        guard !images.isEmpty else { return }
        Haptics.success()
        // Dismiss Studio first so the live import banner on Home isn't hidden behind the cover,
        // then kick off the import after a short beat for the dismiss animation.
        dismiss()
        environment.requestTabSwitch(.home)
        try? await Task.sleep(nanoseconds: 250_000_000)
        await environment.importFromPhotos(images)
    }

    @MainActor
    private func handlePickedVideo(_ item: PhotosPickerItem) async {
        isLoadingMedia = true
        defer { isLoadingMedia = false; pickedVideo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("studio-\(UUID().uuidString).mov")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        Haptics.success()
        dismiss()
        environment.requestTabSwitch(.home)
        try? await Task.sleep(nanoseconds: 250_000_000)
        await environment.importFromVideo(url)
    }
    #endif

    // MARK: Drafts

    @ViewBuilder private var draftsSection: some View {
        let drafts = environment.myDrafts
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("Drafts", count: drafts.count)
            if drafts.isEmpty {
                emptyDrafts
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(drafts) { r in draftCard(r) }
                    }
                }
                .scrollClipDisabled()
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
                })
            }
        }
    }

    private var emptyDrafts: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No drafts yet")
                .font(AppFont.body(14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Recipes you save without publishing land here so you can finish them later.")
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func draftCard(_ recipe: Recipe) -> some View {
        Button {
            Haptics.tap()
            environment.selectRecipe(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(width: 150, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text("Draft")
                            .font(AppFont.body(10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(8)
                    }
                Text(recipe.title)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Button {
                    Haptics.success()
                    environment.publishDraft(recipeId: recipe.id)
                } label: {
                    Text("Publish")
                        .font(AppFont.body(12, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: Published

    @ViewBuilder private var publishedSection: some View {
        let pub = environment.myPublished
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("Published", count: pub.count)
            if pub.isEmpty {
                emptyPublished
            } else {
                LazyVGrid(columns: gridColumns, spacing: AppSpacing.sm) {
                    ForEach(pub) { r in publishedTile(r) }
                }
            }
        }
    }

    private var emptyPublished: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Nothing published yet")
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Tap \u{201C}Publish a new recipe\u{201D} up top. Your recipes show up on the Discover feed and your creator profile.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func publishedTile(_ recipe: Recipe) -> some View {
        Button {
            Haptics.tap()
            environment.selectRecipe(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
                Text(recipe.title)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                Button(role: .destructive) {
                    Haptics.tap()
                    environment.unpublishRecipe(recipeId: recipe.id)
                } label: {
                    Label("Move to Drafts", systemImage: "eye.slash")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(count)")
                .font(AppFont.body(13, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 2)
    }
}
