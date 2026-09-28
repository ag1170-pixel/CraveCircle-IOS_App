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

struct HorizontalScrollFrameKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showingImportSheet: Bool
    @State private var showNotifications = false
    @State private var query = ""                       // search moved here from the old Search tab
    @State private var filters = RecipeFilters()
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
                    searchSection
                    if isSearching {
                        searchResultsSection
                    } else {
                        freshSection
                        if !environment.suggestedRecipes.isEmpty {
                            suggestedSection
                        }
                        librarySection
                    }
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
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
            .navigationDestination(isPresented: $navigateToLibrary) {
                LibraryScreen()
            }
            .sheet(isPresented: $showNotifications) {
                CircleNotificationsSheet()
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

    // MARK: Search (moved here from the old Search tab)

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || filters.isActive
    }

    private var results: [Recipe] {
        RecipeSearch.apply(environment.recipes, query: query, filters: filters)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            searchField.padding(.horizontal, AppSpacing.md)
            filterBar
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            TextField("Search recipes, creators, ingredients", text: $query)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = ""; Haptics.tap() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.textTertiary)
                }.buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 48)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Veg", systemImage: "leaf.fill", isOn: filters.diet == .veg) { setDiet(.veg) }
                FilterChip(title: "Non-veg", systemImage: "fish.fill", isOn: filters.diet == .nonVeg) { setDiet(.nonVeg) }
                FilterChip(title: "Vegan", systemImage: "carrot.fill", isOn: filters.diet == .vegan) { setDiet(.vegan) }
                filterDivider
                FilterChip(title: "Under 15m", systemImage: "bolt.fill", isOn: filters.time == .under15) { setTime(.under15) }
                FilterChip(title: "15–30m", systemImage: "clock.fill", isOn: filters.time == .mid) { setTime(.mid) }
                FilterChip(title: "30m+", systemImage: "clock", isOn: filters.time == .long) { setTime(.long) }
                filterDivider
                FilterChip(title: "High protein", systemImage: "flame.fill", isOn: filters.highProtein) {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filters.highProtein.toggle() }
                }
                if filters.isActive {
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filters = RecipeFilters() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            Text("Clear").font(AppFont.body(14, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .scrollClipDisabled()
    }

    private var filterDivider: some View {
        Rectangle().fill(AppTheme.hairline).frame(width: 1, height: 22).padding(.horizontal, 2)
    }

    private func setDiet(_ d: DietFilter) {
        Haptics.select()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            filters.diet = (filters.diet == d) ? .any : d
        }
    }

    private func setTime(_ t: TimeFilter) {
        Haptics.select()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            filters.time = (filters.time == t) ? .any : t
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if results.isEmpty {
                noResults
            } else {
                let n = results.count
                Text("\(n) \(n == 1 ? "result" : "results")")
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(results) { recipe in
                        LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: results) }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(AppTheme.textTertiary)
            Text(query.isEmpty ? "No recipes match those filters" : "No matches for \u{201C}\(query)\u{201D}")
                .font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Try a different dish, ingredient, or fewer filters.")
                .font(AppFont.body(14)).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xl).padding(.horizontal, AppSpacing.md)
    }

    // MARK: Feed computation
    // "Fresh in your Circle" = recipes from OTHER people (not yours). Your library grid = yours or
    // saved. Both key off ownership, not `canDelete` (a moderation check that's true for any imported
    // recipe, which leaked other creators' recipes into your library and drained the Circle feed).
    private var freshFeedRecipes: [Recipe] {
        let feed = environment.recipes.filter { !environment.isOwner(of: $0) }
        return feed.isEmpty ? environment.recipes : feed
    }

    private var libraryGridRecipes: [Recipe] {
        environment.recipes.filter { environment.isOwner(of: $0) || environment.isSaved(recipeId: $0.id) }
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
                ScrollMoreHint()
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
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
                })
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
                ScrollMoreHint()
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
                        .frame(width: FreshCard.cardWidth) // match the 2-up card width
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .scrollClipDisabled()
            .background(GeometryReader { geo in
                Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
            })
        }
    }

    // MARK: Your Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HomeSectionHeader(title: "Your Library", showViewAll: true) {
                navigateToLibrary = true
            }
            .padding(.horizontal, AppSpacing.md)

            LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                ForEach(libraryGridRecipes) { recipe in
                    LibraryCard(recipe: recipe) { environment.selectRecipe(recipe) }
                }
            }
            .padding(.horizontal, AppSpacing.md)
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
    var onSingleTap: (() -> Void)? = nil
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showBurst = false
    @State private var burstScale: CGFloat = 0.2
    @State private var burstOpacity: Double = 0
    @State private var burstY: CGFloat = 0

    var body: some View {
        ZStack {
            Color.white.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    let liked = environment.isLiked(recipeId: recipeId)
                    if !liked {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                            environment.toggleLikeRecipe(id: recipeId)
                        }
                    }
                    triggerBurst()
                }
                .onTapGesture(count: 1) {
                    if let onSingleTap {
                        Haptics.tap()
                        onSingleTap()
                    }
                }

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

/// Trailing hint on a horizontally-scrolling section header: a gently nudging chevron so users
/// know there's more to the right. Honors Reduce Motion (static arrow, still directional).
struct ScrollMoreHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nudge = false

    var body: some View {
        HStack(spacing: 3) {
            Text("Swipe")
                .font(AppFont.body(12, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .offset(x: nudge ? 3 : 0)
        }
        .foregroundStyle(AppTheme.textTertiary)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { nudge = true }
        }
        .accessibilityHidden(true)
    }
}

struct FreshCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    /// Sized so exactly two cards fill the screen width (md gutters on both sides + between).
    static var cardWidth: CGFloat { (UIScreen.main.bounds.width - AppSpacing.md * 3) / 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover(recipe)
                .frame(width: Self.cardWidth, height: Self.cardWidth * 0.78)
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
                .overlay { CardLikeOverlay(recipeId: recipe.id, onSingleTap: onTap) }
            Text(recipe.title)
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            CreatorLine(handle: recipe.ownerUsername)
            MetaLine(recipe: recipe)
        }
        .frame(width: Self.cardWidth, alignment: .leading)
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
            // Definite 1.1 aspect box so every card's cover is the SAME height (the cover() helper is a
            // GeometryReader with no intrinsic size, so it needs a sized container to fill).
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(1.1, contentMode: .fit)
                .overlay { cover(recipe) }
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
                .overlay { CardLikeOverlay(recipeId: recipe.id, onSingleTap: onTap) }
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
        RecipeCoverImage(urlString: recipe.thumbnailUrl)
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
