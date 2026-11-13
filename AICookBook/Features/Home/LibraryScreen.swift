//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: LibraryScreen.swift
// ==============================================================================
//
// 1. PURPOSE:
//    User's personal recipe repository housing saved, imported, and created dishes.
//
// 2. ARCHITECTURAL ROLE:
//    Tab-based library manager with category filters (All, Saved, Created, Imported) and collection organization.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "LibraryScreen represents the user's permanent cookbook. It filters dishes by origin, supports custom recipe collections, and provides fast search across saved recipes."
//
// ==============================================================================
//

//
//  LibraryScreen.swift
//  CraveCircle (AICookBook)
//
//  Your Library — every recipe you've imported or saved, in one grid with filters.
//  Reuses the photo-dominant RecipeCard. Coral + cream.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct LibraryScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var filter = 0   // 0 All, 1 Liked, 2 Saved, 3 Created

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    private var filteredRecipes: [Recipe] {
        switch filter {
        case 1: // Liked
            return environment.likedRecipes
        case 2: // Saved
            return environment.savedRecipes
        case 3: // Created — written here, not imported
            return environment.createdRecipes
        default: // All
            return environment.myLibraryRecipes
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                LimeSegmentedControl(
                    segments: [
                        "All \(environment.myLibraryRecipes.count)",
                        "Liked \(environment.likedRecipeIds.count)",
                        "Saved \(environment.savedRecipes.count)",
                        "Created \(environment.createdRecipes.count)"
                    ],
                    selection: $filter
                )

                if filteredRecipes.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: filter == 1 ? "heart.slash" : (filter == 2 ? "bookmark.slash" : "tray"))
                            .font(.system(size: 32))
                            .foregroundStyle(filter == 1 ? Color(hex: "FF2D55") : AppTheme.textTertiary)
                        Text(filter == 1 ? "No liked recipes yet" : (filter == 2 ? "No saved recipes" : (filter == 3 ? "No recipes you wrote" : "No recipes found")))
                            .font(AppFont.body(16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(filter == 1 ? "Double-tap any cooking photo to heart it and save it to your liked list." : (filter == 2 ? "Save recipes to find them quickly here." : (filter == 3 ? "Write a recipe and it shows up here. Imports stay in All." : "Import or author recipes to see them here.")))
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xxl)
                } else {
                    LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                        ForEach(filteredRecipes) { recipe in
                            LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: filteredRecipes) }
                                .onAppear {
                                    // Infinite scroll: load the next page as the last card appears
                                    // (only on the full "All" list — the other tabs are local subsets).
                                    if filter == 0, recipe.id == filteredRecipes.last?.id {
                                        Task { await environment.loadMoreRecipes() }
                                    }
                                }
                        }
                    }
                    if filter == 0 && environment.isLoadingMore {
                        ProgressView()
                            .tint(AppTheme.accentInk)
                            .frame(width: 36, height: 36)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppScreenBackground())
        .scrollIndicators(.hidden)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if environment.recipes.isEmpty { await environment.refreshRecipes() }
        }
        .tint(AppTheme.accentInk)
    }
}
