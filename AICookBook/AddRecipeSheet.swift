//
//  AddRecipeSheet.swift
//  CraveCircle (AICookBook)
//
//  One-step "Add a recipe" sheet (structure inspired by Osta, UI is our cream/charcoal brand).
//  Opens from the Import (+) tab button. Four ways in: paste a social/web link, write from
//  scratch, or OCR a photo. Personal-use only — social imports stay private to the importer.
//

import SwiftUI
import PhotosUI

struct AddRecipeSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showing: Bool

    @State private var link = ""
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showWrite = false
    @State private var showLink = false            // paste field is hidden until "Import from social media" is tapped
    @State private var blank = AddRecipeSheet.newBlank()
    @State private var contentHeight: CGFloat = 0  // drives a content-fitted sheet detent (no dead space)
    @FocusState private var linkFocused: Bool

    // Fit the sheet to its content; cap at 90% so a small screen still scrolls. Falls back before measure.
    private var detentHeight: CGFloat {
        contentHeight > 0 ? min(contentHeight, UIScreen.main.bounds.height * 0.9) : 440
    }

    private var canImportLink: Bool { ReelURL.isValid(link) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header

                socialBanner

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: AppSpacing.sm), GridItem(.flexible(), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    optionCard("Write from scratch", systemImage: "square.and.pencil") { startWrite() }
                    photoCard
                }

                if showLink {
                    linkField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .background(AppTheme.background)
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showWrite) {
            NavigationStack {
                RecipeEditScreen(recipe: Binding(get: { blank }, set: { blank = $0 })) { saved in
                    environment.updateRecipe(saved)
                    showWrite = false
                    showing = false
                }
                .environmentObject(environment)
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                showing = false
                await environment.importFromPhoto(img)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Add a recipe")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button { Haptics.tap(); showing = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.surface, in: Circle())
                    .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Social banner (paste a reel link)

    private var socialBanner: some View {
        Button { Haptics.tap(); revealLinkField() } label: {
            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 22))
                    Image(systemName: "play.rectangle.fill").font(.system(size: 22))
                    Image(systemName: "music.note").font(.system(size: 20))
                }
                .foregroundStyle(AppTheme.accent)
                Text("Import from social media")
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Instagram · TikTok · YouTube — paste a cooking-reel link")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Option cards

    private func optionCard(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: { cardBody(title, systemImage) }
            .buttonStyle(PressableStyle())
    }

    private var photoCard: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            cardBody("Import from photo", "photo")
        }
        .buttonStyle(PressableStyle())
    }

    private func cardBody(_ title: String, _ systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(height: 30)
            Text(title)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Paste link field

    private var linkField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "link").font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.textTertiary)
            TextField("Import from link", text: $link)
                .font(AppFont.body(15))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($linkFocused)
            Button {
                Haptics.tap()
                let url = link
                showing = false
                Task { await environment.startImport(from: url) }
            } label: {
                Text("Import")
                    .font(AppFont.body(14, weight: .bold))
                    .foregroundStyle(canImportLink ? AppTheme.onAccent : AppTheme.textTertiary)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(canImportLink ? AppTheme.accent : AppTheme.accentSoft, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canImportLink)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 52)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Reveal + focus the paste-link field (from the social-media option)

    private func revealLinkField() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLink = true }
        // Field is mounted after the state change renders; focus on the next runloop tick so it sticks.
        DispatchQueue.main.async { linkFocused = true }
    }

    // MARK: Blank recipe for "Write from scratch"

    private func startWrite() { blank = AddRecipeSheet.newBlank(); showWrite = true }

    static func newBlank() -> Recipe {
        Recipe(
            id: "draft-\(UUID().uuidString.prefix(8))",
            ownerId: AppEnvironment.shared?.currentUser?.id ?? "local-chef",
            title: "",            // empty → the "Recipe Name" placeholder shows instead of pre-filled text
            description: "",
            prepTime: nil,
            cookTime: nil,
            servings: 2,
            ingredients: [IngredientGroup(groupName: nil, items: [""])],
            directions: [DirectionStep(stepIndex: 1, text: "")],
            thumbnailUrl: nil,
            ownerUsername: AppEnvironment.shared?.currentUser?.username ?? "@you"
        )
    }
}
