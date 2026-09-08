//
//  HomeScreen.swift
//  CraveCircle (AICookBook)
//
//  Browse surface, matched to the Figma "Main Dashboard": serif wordmark top bar,
//  a "Following" creators row, "Fresh in your Circle" horizontal cards, and a
//  "Your Library" grid — cards carry title/creator/meta below the image.
//  Light-first warm/coral, full dark parity.
//

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showingImportSheet: Bool
    @State private var showNotifications = false
    @State private var selectedCreator: Creator?
    @State private var navigateToFriends = false
    @State private var navigateToLibrary = false
    @State private var showShared = false
    @AppStorage("last_opened_shared_screen") private var lastOpenedSharedScreen: Double = 0
    
    private var unreadSharedCount: Int {
        let lastDate = Date(timeIntervalSince1970: lastOpenedSharedScreen)
        let myId = environment.currentUser?.id ?? "me"
        return environment.sharedLog.filter { 
            ($0.toUserId == myId || $0.toUserId == "me") && $0.createdAt > lastDate 
        }.count
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    followingSection
                    freshSection
                    if !environment.suggestedRecipes.isEmpty {
                        suggestedSection
                    }
                    librarySection
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 120)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .refreshable { 
                await environment.refreshRecipes()
                await environment.fetchSuggestedFeed()
            }
            .task {
                if environment.suggestedRecipes.isEmpty {
                    await environment.fetchSuggestedFeed()
                }
            }
            .safeAreaInset(edge: .top) { topBar }
            .navigationDestination(isPresented: $navigateToFriends) {
                FriendsScreen()
            }
            .navigationDestination(isPresented: $navigateToLibrary) {
                LibraryScreen()
            }
            .sheet(isPresented: $showNotifications) {
                CircleNotificationsSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedCreator) { creator in
                CreatorProfileSheet(handle: creator.handle, name: creator.name)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showShared) {
                SharedScreen()
            }
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: Top bar (brand)

    private var topBar: some View {
        ZStack {
            // Centered brand (Figma alignment)
            HStack(spacing: 8) {
                BrandMark()
                Text("CraveCircle")
                    .font(AppFont.serif(24, weight: .bold))
                    .italic()
                    .foregroundStyle(AppTheme.textPrimary)
            }
            // Leading: mail (shared inbox) top-left. Trailing: import + bell.
            HStack(spacing: AppSpacing.xs) {
                iconButton("envelope", label: unreadSharedCount > 0 ? "Shared with you, \(unreadSharedCount) new" : "Shared with you", badgeCount: unreadSharedCount) {
                    Haptics.tap()
                    lastOpenedSharedScreen = Date().timeIntervalSince1970
                    showShared = true
                }
                Spacer()
                iconButton("square.and.arrow.down", label: "Import a recipe") { Haptics.tap(); showingImportSheet = true }
                iconButton("bell", label: "Notifications") { Haptics.tap(); showNotifications = true }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        // Match the app background so the brand sits on the app's own color, not a lighter panel.
        .background(AppTheme.background)
    }

    private func iconButton(_ symbol: String, label: String, badgeCount: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                
                if let count = badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    // MARK: Following

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HomeSectionHeader(title: "Following", showViewAll: true) {
                navigateToFriends = true
            }
            .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(Creator.samples) { creator in
                        Button {
                            Haptics.tap()
                            selectedCreator = creator
                        } label: {
                            CreatorChip(creator: creator)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Feed computation
    private var freshFeedRecipes: [Recipe] {
        let feed = environment.recipes.filter { !environment.canDelete($0) }
        return feed.isEmpty ? environment.recipes : feed
    }

    private var libraryGridRecipes: [Recipe] {
        Array(environment.myLibraryRecipes.prefix(6))
    }

    // MARK: Fresh in your Circle

    private var freshSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Fresh in your Circle")
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("new today !!")
                    .font(AppFont.serif(15, weight: .semibold))
                    .italic()
                    .foregroundStyle(AppTheme.accentInk)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)

            if freshFeedRecipes.isEmpty {
                EmptyRecipesState { showingImportSheet = true }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ForEach(freshFeedRecipes) { recipe in
                            FreshCard(recipe: recipe) { environment.selectRecipe(recipe) }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .scrollClipDisabled()
            }
        }
    }
    
    // MARK: Suggested for You
    
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color(hex: "FFB340"))
                    .font(.system(size: 18, weight: .semibold))
                Text("Suggested for You")
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    ForEach(environment.suggestedRecipes) { recipe in
                        VStack(alignment: .leading, spacing: 6) {
                            FreshCard(recipe: recipe) { environment.selectRecipe(recipe, in: environment.suggestedRecipes) }
                            if let why = environment.suggestionReasons[recipe.id] {
                                SuggestionReasonChip(text: why)
                                    .frame(maxWidth: 200, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Your Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HomeSectionHeader(title: "Your Library", showViewAll: true) {
                navigateToLibrary = true
            }
            .padding(.horizontal, AppSpacing.md)

            if libraryGridRecipes.isEmpty {
                EmptyRecipesState { showingImportSheet = true }
                    .padding(.horizontal, AppSpacing.md)
            } else {
                LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                    ForEach(libraryGridRecipes) { recipe in
                        LibraryCard(recipe: recipe) { environment.selectRecipe(recipe) }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }
}

// MARK: - Brand mark (coral chef-hat)

struct BrandMark: View {
    var body: some View {
        ChefHatLogo(size: 28)
    }
}

// MARK: - Section header with optional "View all"

struct HomeSectionHeader: View {
    let title: String
    var showViewAll: Bool = false
    var onViewAll: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.display(20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if showViewAll {
                Button {
                    Haptics.tap()
                    onViewAll?()
                } label: {
                    Text("View all")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Creator chip

struct CreatorChip: View {
    let creator: Creator
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        let following = environment.isFollowing(creatorHandle: creator.handle)
        VStack(spacing: 6) {
            Circle()
                .fill(AppTheme.accentSoft)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(creator.initials)
                        .font(AppFont.serif(20, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                )
                .overlay(Circle().stroke(following ? AppTheme.accent : AppTheme.hairline, lineWidth: following ? 2 : 1).padding(-3))
            HStack(spacing: 3) {
                Text(creator.handle)
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.accentInk)
            }
        }
        .frame(width: 76)
    }
}

// MARK: - Fresh card (horizontal)

/// Full-cover overlay for a recipe card: a like heart pinned bottom-right (like straight from the
/// grid) PLUS the same Instagram heart-burst the recipe page shows — a big heart that pops and
/// floats up, centred over the card photo, when you like. Applied as `.overlay { … }` on the cover.
struct CardLikeOverlay: View {
    let recipeId: String
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showBurst = false
    @State private var burstScale: CGFloat = 0.2
    @State private var burstOpacity: Double = 0
    @State private var burstY: CGFloat = 0

    var body: some View {
        ZStack {
            if showBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "FF2D55"), Color(hex: "FF375F"), Color(hex: "FF7A00")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .scaleEffect(burstScale)
                    .opacity(burstOpacity)
                    .offset(y: burstY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    heartButton
                }
            }
        }
    }

    private var heartButton: some View {
        let liked = environment.isLiked(recipeId: recipeId)
        return Button {
            let wasLiked = liked
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                environment.toggleLikeRecipe(id: recipeId)
            }
            if !wasLiked { triggerBurst() }   // burst only when liking (matches the recipe page)
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(liked ? Color.red : .white)
                .padding(7)
                .background(.black.opacity(0.32), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .scaleEffect(liked ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .padding(8)
        .accessibilityLabel(liked ? "Unlike recipe" : "Like recipe")
    }

    private func triggerBurst() {
        guard !reduceMotion else { return }
        showBurst = true; burstScale = 0.2; burstOpacity = 0.95; burstY = 0
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { burstScale = 1.15 }
        withAnimation(.easeInOut(duration: 0.45).delay(0.3)) {
            burstScale = 1.3; burstOpacity = 0; burstY = -22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showBurst = false }
    }
}

struct FreshCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover(recipe)
                .frame(width: 168, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if recipe.visibility == .followers {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                            .padding(6)
                            .background(AppTheme.accentSoft.opacity(0.9), in: Circle())
                            .padding(8)
                    }
                }
                .overlay { CardLikeOverlay(recipeId: recipe.id) }
            Text(recipe.title)
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            CreatorLine(handle: recipe.ownerUsername)
            MetaLine(recipe: recipe)
        }
        .frame(width: 168, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); onTap() }
        .contextMenu {
            let saved = environment.isSaved(recipeId: recipe.id)
            Button {
                Haptics.select()
                environment.toggleSaveRecipe(id: recipe.id)
            } label: {
                Label(saved ? "Remove from Saved" : "Save Recipe", systemImage: saved ? "bookmark.fill" : "bookmark")
            }
            Button {
                Haptics.tap()
                environment.selectRecipe(recipe)
            } label: {
                Label("View Details", systemImage: "eye")
            }
        }
    }
}

// MARK: - Library card (grid)

struct LibraryCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover(recipe)
                .aspectRatio(1.1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(AppTheme.accentSoft)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text(recipe.ownerUsername?.replacingOccurrences(of: "@", with: "").prefix(2).uppercased() ?? "CC")
                                .font(AppFont.serif(12, weight: .bold))
                                .foregroundStyle(AppTheme.accentInk)
                        )
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .padding(10)
                }
                .overlay(alignment: .topTrailing) {
                    if recipe.visibility == .followers {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                            .padding(6)
                            .background(AppTheme.accentSoft.opacity(0.9), in: Circle())
                            .padding(8)
                    }
                }
                .overlay { CardLikeOverlay(recipeId: recipe.id) }
            Text(recipe.title)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            CreatorLine(handle: recipe.ownerUsername)
            if let s = recipe.servings {
                Text("\(s) servings")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); onTap() }
        .contextMenu {
            let saved = environment.isSaved(recipeId: recipe.id)
            Button {
                Haptics.select()
                environment.toggleSaveRecipe(id: recipe.id)
            } label: {
                Label(saved ? "Remove from Saved" : "Save Recipe", systemImage: saved ? "bookmark.fill" : "bookmark")
            }
            Button {
                Haptics.tap()
                environment.selectRecipe(recipe)
            } label: {
                Label("View Recipe", systemImage: "fork.knife")
            }
            if environment.canDelete(recipe) {
                Button(role: .destructive) {
                    environment.deleteOwnedRecipe(id: recipe.id)
                } label: {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Cover image helper

@ViewBuilder
func cover(_ recipe: Recipe) -> some View {
    GeometryReader { geo in
        Group {
            if let thumb = recipe.thumbnailUrl, UIImage(named: thumb) != nil {
                Image(thumb).resizable()
            } else if let urlString = recipe.thumbnailUrl, let url = URL(string: urlString), (url.scheme == "http" || url.scheme == "https" || url.scheme == "file") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        RecipeImagePlaceholder(isBuffering: false, size: 28)
                    case .empty:
                        RecipeImagePlaceholder(isBuffering: true, size: 28)
                    @unknown default:
                        RecipeImagePlaceholder(isBuffering: false, size: 28)
                    }
                }
            } else {
                RecipeImagePlaceholder(isBuffering: false, size: 28)
            }
        }
        .scaledToFill()
        .frame(width: geo.size.width, height: geo.size.height)
        .clipped()
    }
}

struct CreatorLine: View {
    let handle: String?
    var body: some View {
        HStack(spacing: 3) {
            Text(handle ?? "@cravecircle")
                .font(AppFont.body(12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.accentInk)
        }
    }
}

struct MetaLine: View {
    let recipe: Recipe
    var body: some View {
        let parts = [
            recipe.servings.map { "\($0) servings" },
            recipe.prepTime.map { "\($0) prep" },
            recipe.cookTime.map { "\($0) cook" }
        ].compactMap { $0 }
        Text(parts.joined(separator: " · "))
            .font(AppFont.body(11, weight: .medium))
            .foregroundStyle(AppTheme.accentInk)
            .lineLimit(1)
    }
}

// MARK: - Empty state

struct EmptyRecipesState: View {
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "fork.knife")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No recipes yet")
                .font(AppFont.display(20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Paste a reel link and CraveCircle turns it into a recipe you can actually cook.")
                .font(AppFont.body(15))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            PillButton(title: "Import a recipe", systemImage: "square.and.arrow.down", kind: .filled, action: onImport)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Sample creators (scaffold until social backend)

struct Creator: Identifiable {
    let id = UUID()
    let handle: String
    let name: String?
    let initials: String

    init(handle: String, name: String? = nil) {
        self.handle = handle
        self.name = name
        let clean = handle.replacingOccurrences(of: "@", with: "")
        self.initials = String(clean.prefix(2)).uppercased()
    }

    static let samples: [Creator] = [
        .init(handle: "@nada_dl", name: "Nada Al-Hassan"),
        .init(handle: "@Aditya.Gupta", name: "Aditya Gupta"),
        .init(handle: "@Kristy.Graver", name: "Kristy Graver"),
        .init(handle: "@Sanjeev.Kapoor", name: "Sanjeev Kapoor"),
        .init(handle: "@zaatarandzeal", name: "Zaatar & Zeal"),
        .init(handle: "@priyacooks", name: "Priya Menon"),
        .init(handle: "@deveats", name: "Dev Sharma"),
        .init(handle: "@aishaskitchen", name: "Aisha Khan"),
        .init(handle: "@chefbot", name: "Chef Bot"),
        .init(handle: "@aicookbook", name: "CraveCircle")
    ]
}
