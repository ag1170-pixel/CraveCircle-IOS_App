//
//  AddRecipeSheet.swift
//  CraveCircle (AICookBook)
//
//  One-step "Add a recipe" sheet (structure inspired by Osta, UI is our cream/charcoal brand).
//  Opens from the Import (+) tab button. Four ways in: paste a social/web link, write from
//  scratch, or OCR a photo. Personal-use only — social imports stay private to the importer.
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif

struct AddRecipeSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showing: Bool

    @State private var link = ""
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var importingPhotos = false
    @State private var showWrite = false
    @State private var showWeb = false
    @State private var showLink = false            // paste field is hidden until "Import from social media" is tapped
    @State private var blank = AddRecipeSheet.newBlank()
    @State private var contentHeight: CGFloat = 0  // drives a content-fitted sheet detent (no dead space)
    @State private var showCreatorRequest = false
    @State private var showStudio = false
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

                // Studio banner only shows up as its own card when the user is already a creator
                // (so the Studio page is one tap from +). For regular users the entry sits inside
                // the grid below as another small tile, matching the other import options.
                if environment.canPublish || environment.hasPendingCreatorRequest {
                    studioBanner
                }

                socialBanner

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: AppSpacing.sm), GridItem(.flexible(), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    optionCard("Write from scratch", systemImage: "square.and.pencil") { startWrite() }
                    optionCard("Import from web", systemImage: "globe") { showWeb = true }
                    photoCard
                    if !environment.canPublish && !environment.hasPendingCreatorRequest {
                        optionCard("Become a Creator", systemImage: "person.badge.plus") {
                            showCreatorRequest = true
                        }
                    }
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
        .fullScreenCover(isPresented: $showWeb) {
            WebImportScreen {
                showWeb = false
                showing = false
            }
            .environmentObject(environment)
        }
        .sheet(isPresented: $showCreatorRequest) {
            CreatorRequestSheet()
                .environmentObject(environment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showStudio) {
            NavigationStack { StudioScreen() }
                .environmentObject(environment)
        }
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
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty, !importingPhotos else { return }
            importingPhotos = true
            Task {
                var images: [UIImage] = []
                for item in items.prefix(6) {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        images.append(img)
                    }
                }
                pickedPhotos = []
                importingPhotos = false
                guard !images.isEmpty else { return }
                showing = false
                await environment.importFromPhotos(images)
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

    // MARK: Studio / Become-a-Creator banner (top of the import sheet)

    @ViewBuilder private var studioBanner: some View {
        if environment.canPublish {
            // Approved creator / admin — straight to the Studio.
            Button {
                Haptics.tap()
                showStudio = true
            } label: {
                studioCard(
                    icon: "sparkles",
                    title: "Open Studio",
                    subtitle: "Publish a new recipe · Share a photo · Share a video",
                    accent: true
                )
            }
            .buttonStyle(PressableStyle())
        } else if environment.hasPendingCreatorRequest {
            // Submitted — thank-you waiting card. Non-interactive by design.
            studioCard(
                icon: "hourglass",
                title: "Thanks for applying!",
                subtitle: "Your creator request is with our team. You'll be able to publish once an admin approves.",
                accent: false
            )
        } else {
            // Regular user — invite them in.
            Button {
                Haptics.tap()
                showCreatorRequest = true
            } label: {
                studioCard(
                    icon: "person.badge.plus",
                    title: "Become a Creator",
                    subtitle: "Share your own recipes with everyone on CraveCircle.",
                    accent: true
                )
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func studioCard(icon: String, title: String, subtitle: String, accent: Bool) -> some View {
        // Charcoal (accent) tile, not coral — the brand/coral is logo-only per Design-Philosophy.md.
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent ? AppTheme.onAccent : AppTheme.accentInk)
                .frame(width: 40, height: 40)
                .background(accent ? AppTheme.accent : AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            if accent {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(accent ? AppTheme.accent.opacity(0.35) : AppTheme.hairline, lineWidth: 1)
        )
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
        PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 6, matching: .images) {
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
            ownerId: AppEnvironment.shared?.currentUser?.id ?? "",
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
