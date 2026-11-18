//
//  CommunityRecipesScreen.swift
//  CraveCircle (AICookBook)
//
//  The full Community Recipes list, opened from the › on Home. Home shows a short preview;
//  here every community recipe is reachable, revealed 10 at a time as you scroll.
//

import SwiftUI

struct CommunityRecipesScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var visibleCount = Self.batchSize
    @State private var isRevealing = false
    private static let batchSize = 10

    private var recipes: [Recipe] {
        environment.recipes.filter { !environment.isDraft(recipeId: $0.id) }
    }
    private var visible: [Recipe] { Array(recipes.prefix(visibleCount)) }
    private var hasMore: Bool { visibleCount < recipes.count || environment.hasMoreRecipes }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.md, alignment: .top),
                GridItem(.flexible(), spacing: AppSpacing.md, alignment: .top)
            ], spacing: AppSpacing.md) {
                ForEach(visible) { recipe in
                    SuggestedGridCard(recipe: recipe) {
                        environment.selectRecipe(recipe, in: visible)
                    }
                    .onAppear {
                        if recipe.id == visible.last?.id { revealMore() }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            if isRevealing {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .accessibilityLabel("Loading more recipes")
            } else if !hasMore {
                Text("You're all caught up")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppScreenBackground())
        .navigationTitle("Community Recipes")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Next batch of 10 when the last card scrolls in; fetches another page from the server
    /// first when the phone has run out of loaded recipes.
    private func revealMore() {
        guard !isRevealing, hasMore else { return }
        isRevealing = true
        Task {
            if visibleCount + Self.batchSize > recipes.count {
                await environment.loadMoreRecipes()
            } else {
                try? await Task.sleep(for: .milliseconds(350))
            }
            visibleCount = min(visibleCount + Self.batchSize, recipes.count)
            isRevealing = false
        }
    }
}
