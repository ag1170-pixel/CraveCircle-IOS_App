//
//  HomeScreen.swift
//  CraveCircle (AICookBook)
//
//  Browse surface, matched to the Figma "Main Dashboard": serif wordmark top bar,
//  then Your Library grid, Fresh in your Circle, and Suggested for You last.
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
    @State private var catHeld = false                   // true while dragging the chef-cat → freeze scroll
    @StateObject private var voiceSearch = VoiceSearchController()
    @FocusState private var searchFocused: Bool
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

    // Swiggy-style rotating search terms — only the quoted word cycles ("Search for 'pasta'").
    static let searchHints = ["pasta", "paneer", "cake", "biryani", "butter chicken", "something sweet"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Brand header lives INSIDE the scroll content so it scrolls away as you scroll
                    // down and returns at the top (Instagram-style), instead of staying pinned.
                    topBar
                    searchSection
                    if isSearching {
                        searchResultsSection
                    } else {
                        if !libraryGridRecipes.isEmpty {
                            librarySection
                        }
                        freshSection
                        if !environment.suggestedRecipes.isEmpty {
                            suggestedSection
                        }
                    }
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .doodleScreenBackground()   // static wallpaper behind text/gaps; cards stay opaque
            .overlayPreferenceValue(CardFramesKey.self) { frames in
                CatCompanion(cardFrames: frames, catHeld: $catHeld)   // peeks, walks, and is draggable
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(catHeld)          // don't let the page scroll (and cancel the drag) while held
            .refreshable {
                await environment.refreshRecipes()
                await environment.fetchSuggestedFeed()
            }
            .task {
                if environment.suggestedRecipes.isEmpty {
                    await environment.fetchSuggestedFeed()
                }
            }
            // The "Search" quick action lands here and asks for the search box to be keyboard-ready.
            .onChange(of: environment.pendingSearchFocus) { _, want in
                if want { focusSearchSoon() }
            }
            .onAppear {
                if environment.pendingSearchFocus { focusSearchSoon() }
            }
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
            // Mail removed; import moved to the tab bar (+). Only the notifications bell remains (right).
            HStack {
                Spacer()
                iconButton("bell", label: "Notifications") { Haptics.tap(); showNotifications = true }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        // Transparent so the wallpaper runs uniformly behind the brand bar too (no opaque strip "cut").
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

    /// Focus the search box after the Home tab has settled on screen (focus set during the tab
    /// switch gets dropped), scrolling the field into view by clearing any active search first.
    private func focusSearchSoon() {
        environment.pendingSearchFocus = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { searchFocused = true }
    }

    private var searchResult: RecipeSearch.Result {
        RecipeSearch.search(environment.recipes, query: query, filters: filters)
    }
    private var results: [Recipe] { searchResult.recipes }

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
            TextField("", text: $query)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .overlay(alignment: .leading) {
                    if query.isEmpty {
                        CyclingPlaceholder(prefix: "Search for ", phrases: Self.searchHints)
                            .allowsHitTesting(false)
                    }
                }
            if !query.isEmpty {
                Button { query = ""; Haptics.tap() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.textTertiary)
                }.buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            micButton
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 50)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(voiceSearch.isRecording ? AppTheme.accent : AppTheme.hairline,
                                  lineWidth: voiceSearch.isRecording ? 1.5 : 1))
        // Live dictation flows straight into the query as the user speaks.
        .onChange(of: voiceSearch.transcript) { _, t in
            if !t.isEmpty { query = t }
        }
    }

    /// Tap to search by voice; shows a listening state while recording. Routes to Settings if the
    /// user previously denied mic/speech access.
    private var micButton: some View {
        Button {
            if voiceSearch.permissionDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                return
            }
            voiceSearch.toggle()
        } label: {
            Image(systemName: voiceSearch.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(voiceSearch.isRecording ? AppTheme.accent : AppTheme.textTertiary)
                .symbolEffect(.variableColor.iterative, isActive: voiceSearch.isRecording)
                .scaleEffect(voiceSearch.isRecording ? 1.12 : 1)
                .animation(AppMotion.snappy, value: voiceSearch.isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceSearch.isRecording ? "Stop voice search" : "Search by voice")
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Veg", systemImage: "leaf", isOn: filters.diet == .veg) { setDiet(.veg) }
                FilterChip(title: "Non-veg", systemImage: "frying.pan", isOn: filters.diet == .nonVeg) { setDiet(.nonVeg) }
                FilterChip(title: "Vegan", systemImage: "carrot", isOn: filters.diet == .vegan) { setDiet(.vegan) }
                filterDivider
                FilterChip(title: "Under 15m", systemImage: "timer", isOn: filters.time == .under15) { setTime(.under15) }
                FilterChip(title: "15–30m", systemImage: "clock.fill", isOn: filters.time == .mid) { setTime(.mid) }
                FilterChip(title: "30m+", systemImage: "clock", isOn: filters.time == .long) { setTime(.long) }
                filterDivider
                FilterChip(title: "High protein", systemImage: "dumbbell", isOn: filters.highProtein) {
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
        // Report this horizontal strip so the tab-switch swipe ignores it (otherwise a sideways
        // swipe on the filter chips flips to the next tab instead of scrolling the chips).
        .background(GeometryReader { geo in
            Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
        })
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
        let result = searchResult
        let recipes = result.recipes
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if recipes.isEmpty {
                noResults
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isGuess ? "No exact match" : "\(recipes.count) \(recipes.count == 1 ? "result" : "results")")
                        .font(AppFont.display(20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if result.isGuess {
                        Text("Here's what you might be craving instead")
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(recipes) { recipe in
                        LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: recipes) }
                            .reportsCardFrame(id: "res-\(recipe.id)", liked: environment.isLiked(recipeId: recipe.id))
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
        let pool = environment.recipes.filter { !environment.isOwner(of: $0) && !$0.isImportedFromSocial }
        return Self.interleaveForDiscovery(pool)
    }

    /// High-diversity carousel ordering: ensures adjacent dishes NEVER share the same category,
    /// so the user experiences an authentic, mouth-watering mix (e.g. curry -> snack -> Italian -> rice -> dessert -> breakfast).
    static func interleaveForDiscovery(_ list: [Recipe]) -> [Recipe] {
        guard list.count > 1 else { return list }
        
        enum Bucket: Int, CaseIterable {
            case poultryMeat   // Butter chicken, burger, wings, tacos, rogan josh
            case vegetarian    // Dal makhani, palak paneer, shahi paneer, chole
            case streetSnack   // Samosa chaat, pav bhaji, gyoza, falafel
            case riceGrains    // Biryani, risotto, udon, bibimbap
            case breakfastDosa // Masala dosa, pancakes, avocado toast
            case continental   // Pizza, rigatoni, pasta, salmon, summer rolls
            case sweetDessert  // Gulab jamun, tiramisu, lava cake
            
            static func category(for r: Recipe) -> Bucket {
                let s = "\(r.title) \(r.description ?? "")".lowercased()
                if s.contains("dosa") || s.contains("pancake") || s.contains("toast") || s.contains("waffle") || s.contains("crepe") { return .breakfastDosa }
                if s.contains("jamun") || s.contains("cake") || s.contains("tiramisu") || s.contains("dessert") || s.contains("sweet") { return .sweetDessert }
                if s.contains("biryani") || s.contains("rice") || s.contains("risotto") || s.contains("udon") || s.contains("bibimbap") || s.contains("pulao") { return .riceGrains }
                if s.contains("chaat") || s.contains("samosa") || s.contains("pav bhaji") || s.contains("gyoza") || s.contains("falafel") || s.contains("bhel") { return .streetSnack }
                if s.contains("pizza") || s.contains("rigatoni") || s.contains("pasta") || s.contains("salmon") || s.contains("summer roll") || s.contains("shrimp") || s.contains("soup") { return .continental }
                if s.contains("chicken") || s.contains("burger") || s.contains("wing") || s.contains("taco") || s.contains("beef") || s.contains("meat") || s.contains("rogan") || s.contains("pork") { return .poultryMeat }
                return .vegetarian
            }
        }
        
        var buckets: [Bucket: [Recipe]] = [:]
        for r in list {
            let cat = Bucket.category(for: r)
            buckets[cat, default: []].append(r)
        }
        
        var result: [Recipe] = []
        result.reserveCapacity(list.count)
        
        var remainingBuckets = Bucket.allCases.filter { buckets[$0]?.isEmpty == false }
        var lastBucket: Bucket? = nil
        
        while !remainingBuckets.isEmpty {
            let candidates = remainingBuckets.filter { $0 != lastBucket }
            guard let next = candidates.first ?? remainingBuckets.first else { break }
            
            if var items = buckets[next], !items.isEmpty {
                result.append(items.removeFirst())
                if items.isEmpty {
                    buckets.removeValue(forKey: next)
                    remainingBuckets.removeAll(where: { $0 == next })
                } else {
                    buckets[next] = items
                }
                lastBucket = next
            } else {
                remainingBuckets.removeAll(where: { $0 == next })
            }
        }
        
        return spreadLookalikes(result)
    }

    /// Keep dishes that read as the same plate (dosa, rice, paneer…) from sitting next to each other.
    static func spreadLookalikes(_ list: [Recipe]) -> [Recipe] {
        func family(_ r: Recipe) -> String {
            let s = r.title.lowercased()
            for key in ["dosa", "idli", "rice", "biryani", "pulao", "paneer", "chicken", "pasta", "cake", "dal"] {
                if s.contains(key) { return key }
            }
            return "other-\(r.id)"
        }
        var pool = list
        var out: [Recipe] = []
        out.reserveCapacity(list.count)
        while !pool.isEmpty {
            let last = out.last.map(family)
            if let i = pool.firstIndex(where: { family($0) != last }) {
                out.append(pool.remove(at: i))
            } else {
                out.append(pool.removeFirst())
            }
        }
        return out
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
                                .reportsCardFrame(id: "fresh-\(recipe.id)", liked: environment.isLiked(recipeId: recipe.id))
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
            }
            .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    ForEach(environment.suggestedRecipes) { recipe in
                        VStack(alignment: .leading, spacing: 6) {
                            FreshCard(recipe: recipe) { environment.selectRecipe(recipe, in: environment.suggestedRecipes) }
                                .reportsCardFrame(id: "sugg-\(recipe.id)", liked: environment.isLiked(recipeId: recipe.id))
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
                        .reportsCardFrame(id: "lib-\(recipe.id)", liked: environment.isLiked(recipeId: recipe.id))
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
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(AppFont.display(20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            if showViewAll {
                Button {
                    Haptics.tap()
                    onViewAll?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View all")
            }
            Spacer()
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

struct FreshCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    /// Two cards fit with a slice of the next one peeking on the right — the peek is the cue that
    /// there's more to swipe (no text hint needed). The -24 per card frees ~48pt for that peek.
    static var cardWidth: CGFloat { (UIScreen.main.bounds.width - AppSpacing.md * 3) / 2 - 24 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fixed frame + scaledToFill + clip — no GeometryReader (a grid of them is slow to render).
            RecipeCoverImage(recipe: recipe)
                .scaledToFill()
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
                .overlay { RecipeCoverImage(recipe: recipe).scaledToFill() }
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
        RecipeCoverImage(recipe: recipe)
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
