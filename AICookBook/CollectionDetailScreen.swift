//
//  CollectionDetailScreen.swift
//  CraveCircle (AICookBook)
//
//  Collection detail view displaying all recipes in this collection.
//

import SwiftUI

struct CollectionDetailScreen: View {
    let collection: CollectionItem
    @EnvironmentObject private var environment: AppEnvironment

    private var collectionRecipes: [Recipe] {
        collection.matching(in: environment.recipes)
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                heroCard
                recipesGrid
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accentInk)
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            Image(collection.imageName)
                .resizable().scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 4) {
                if collection.shared {
                    Label("Shared Collection", systemImage: "person.2.fill")
                        .font(AppFont.body(11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Text(collection.name)
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(collectionRecipes.count) curated recipes")
                    .font(AppFont.body(13))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)
        }
    }

    private var recipesGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HomeSectionHeader(title: "Collection Recipes", showViewAll: false)
            if collectionRecipes.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No recipes in this collection yet")
                        .font(AppFont.body(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(collectionRecipes) { recipe in
                        LibraryCard(recipe: recipe) {
                            environment.selectRecipe(recipe)
                        }
                    }
                }
            }
        }
    }
}
