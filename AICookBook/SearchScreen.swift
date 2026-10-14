//
//  SearchScreen.swift
//  CraveCircle (AICookBook)
//
//  "Your Circle" — the people you follow and the recipes they've shared. (Search + filters moved to
//  the Home tab; this tab is the Following/people surface.) Coral + cream.
//

import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedCreator: Creator?
    @State private var navigateToFriends = false

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    /// Recipes from creators the user follows; if they follow no one yet, fall back to everyone
    /// else's recipes so the Circle isn't empty (matches Home's old "Fresh in your Circle").
    private var circleRecipes: [Recipe] {
        // Never other users' social imports — only creator-published / curated content (personal-use).
        let followed = environment.communityFeed.filter { !$0.isImportedFromSocial }
        return followed.isEmpty
            ? environment.recipes.filter { !environment.isOwner(of: $0) && !$0.isImportedFromSocial }
            : followed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Your Circle")
                    .font(AppFont.display(32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)

                followingSection

                if circleRecipes.isEmpty {
                    emptyState
                } else {
                    gridSection("New from your Circle", circleRecipes)
                        .padding(.horizontal, AppSpacing.md)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .task {
            if environment.recipes.isEmpty { await environment.refreshRecipes() }
        }
        .navigationDestination(isPresented: $navigateToFriends) { FriendsScreen() }
        .sheet(item: $selectedCreator) { creator in
            CreatorProfileSheet(handle: creator.handle, name: creator.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .tint(AppTheme.accentInk)
    }

    // MARK: Following creators row

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HomeSectionHeader(title: "Following", showViewAll: true) { navigateToFriends = true }
                .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(Creator.samples) { creator in
                        Button { Haptics.tap(); selectedCreator = creator } label: {
                            CreatorChip(creator: creator)
                        }
                        .buttonStyle(.plain)
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

    private func gridSection(_ title: String, _ recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(recipes) { recipe in
                    LibraryCard(recipe: recipe) { environment.selectRecipe(recipe, in: recipes) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.2").font(.system(size: 32)).foregroundStyle(AppTheme.textTertiary)
            Text("Follow creators to fill your Circle")
                .font(AppFont.body(16, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
            Text("Recipes from the people you follow show up here.")
                .font(AppFont.body(14)).foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - "Why you're seeing this" chip (shared with Home's Suggested section)

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

// MARK: - Filter chip (shared — used by Home's search filter bar)

struct FilterChip: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.monochrome)
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

// MARK: - Wrapping chips (shared)

struct FlowChips: View {
    let tags: [String]
    let onTap: (String) -> Void

    var body: some View {
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
