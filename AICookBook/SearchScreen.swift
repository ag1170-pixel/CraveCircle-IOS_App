//
//  SearchScreen.swift
//  CraveCircle (AICookBook)
//
//  Search & Discover. Ingredient-aware search ("paneer" finds recipes that use it) plus a
//  filter bar — diet, time, high-protein — all inferred on-device (see RecipeSearch). When the
//  query is empty and no filters are on, it shows Suggested / Trending / Discover. Coral + cream.
//

import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var query = ""
    @State private var filters = RecipeFilters()

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]
    private let trending = ["High protein", "15-minute", "Crispy Chicken", "Air fryer", "Italian", "Desi comfort", "Brunch", "Korean"]

    private var results: [Recipe] {
        RecipeSearch.apply(environment.recipes, query: query, filters: filters)
    }

    private var showDiscovery: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty && !filters.isActive
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                searchField
                filterBar

                if showDiscovery {
                    if !environment.suggestedRecipes.isEmpty {
                        suggestedSection
                    }
                    trendingSection
                    gridSection("Discover", results)
                } else if results.isEmpty {
                    noResults
                } else {
                    gridSection(resultsTitle, results)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, 120)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if environment.recipes.isEmpty { await environment.refreshRecipes() }
            await environment.fetchSuggestedFeed()
        }
        .tint(AppTheme.accentInk)
    }

    private var resultsTitle: String {
        let n = results.count
        return "\(n) \(n == 1 ? "result" : "results")"
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

    // MARK: - Filter bar

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
            .padding(.horizontal, 2)
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

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Trending").sectionLabelStyle()
            FlowChips(tags: trending) { tag in
                // A couple of trending tags map to real filters instead of a text query.
                switch tag {
                case "High protein": withAnimation { filters.highProtein = true }
                case "15-minute":    withAnimation { filters.time = .under15 }
                default:             query = tag
                }
            }
        }
    }

    // Suggested grid with a "why you're seeing this" chip under each card.
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Suggested for You")
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(environment.suggestedRecipes) { recipe in
                    VStack(alignment: .leading, spacing: 6) {
                        LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: environment.suggestedRecipes) }
                        if let why = environment.suggestionReasons[recipe.id] {
                            SuggestionReasonChip(text: why)
                        }
                    }
                }
            }
        }
    }

    private func gridSection(_ title: String, _ recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(recipes) { recipe in
                    // Swipe within this section's list (e.g. suggestions), not the whole library.
                    LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: recipes) }
                }
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
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xl)
    }
}

// MARK: - "Why you're seeing this" chip

struct SuggestionReasonChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .semibold))
            Text(text).font(AppFont.body(11, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(AppTheme.accentInk)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(AppTheme.accent.opacity(0.12), in: Capsule())
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
                Text(title).font(AppFont.body(14, weight: .semibold))
            }
            .foregroundStyle(isOn ? AppTheme.onAccent : AppTheme.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(isOn ? AppTheme.accent : AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(isOn ? Color.clear : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Wrapping chips

struct FlowChips: View {
    let tags: [String]
    let onTap: (String) -> Void

    var body: some View {
        // Simple two-row wrap using a LazyVGrid of adaptive chips.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.xs)], alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(tags, id: \.self) { tag in
                Button { Haptics.tap(); onTap(tag) } label: {
                    Text(tag)
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
