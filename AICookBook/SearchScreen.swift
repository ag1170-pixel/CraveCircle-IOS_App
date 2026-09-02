//
//  SearchScreen.swift
//  CraveCircle (AICookBook)
//
//  Search & Discover — matched to the web `search` page. A search field over recipes;
//  when empty, a Discover view with trending tags and a recipe grid. Coral + cream.
//

import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var query = ""

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]
    private let trending = ["High protein", "15-minute", "Crispy Chicken", "Air fryer", "Italian", "Desi comfort", "Brunch", "Korean"]

    private var results: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return environment.recipes }
        return environment.recipes.filter { recipe in
            if q == "high protein" {
                return (recipe.nutrition?.proteinG ?? 0) >= 25
            }
            if q == "15-minute" {
                return (recipe.prepTime?.contains("10") == true) || (recipe.prepTime?.contains("15") == true) || (recipe.cookTime?.contains("10") == true) || (recipe.cookTime?.contains("15") == true)
            }
            if q == "air fryer" {
                return recipe.title.lowercased().contains("wings") || recipe.title.lowercased().contains("chicken") || recipe.title.lowercased().contains("wrap")
            }
            return recipe.title.lowercased().contains(q) ||
            (recipe.ownerUsername?.lowercased().contains(q) ?? false) ||
            (recipe.description?.lowercased().contains(q) ?? false) ||
            recipe.ingredients.contains(where: { group in
                group.items.contains(where: { $0.lowercased().contains(q) })
            })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                searchField

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    trendingSection
                    gridSection("Discover")
                } else if results.isEmpty {
                    noResults
                } else {
                    gridSection("Results")
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
        .task { if environment.recipes.isEmpty { await environment.refreshRecipes() } }
        .tint(AppTheme.accentInk)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            TextField("Search recipes & creators", text: $query)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textPrimary)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = ""; Haptics.tap() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.textTertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 48)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Trending").sectionLabelStyle()
            FlowChips(tags: trending) { query = $0 }
        }
    }

    private func gridSection(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(results) { recipe in
                    LibraryCard(recipe: recipe) { environment.selectRecipe(recipe) }
                }
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(AppTheme.textTertiary)
            Text("No matches for \u{201C}\(query)\u{201D}").font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
            Text("Try a different dish, ingredient, or creator.").font(AppFont.body(14)).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xl)
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
