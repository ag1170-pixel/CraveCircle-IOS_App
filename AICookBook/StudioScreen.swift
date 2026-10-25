//
//  StudioScreen.swift
//  CraveCircle (AICookBook)
//
//  The creator's workspace. One primary CTA — "Publish new recipe" — opens a blank
//  editor via the existing `pendingNewRecipe` hook, so the recipe editor sheet handles
//  the actual authoring. Drafts and already-published recipes live in two tidy sections
//  so a creator can keep working on either without hunting through their library.
//
//  Reaches: environment.myDrafts, myPublished, publishDraft(recipeId:), unpublishRecipe(),
//  pendingNewRecipe, selectRecipe(_:).
//

import SwiftUI

struct StudioScreen: View {
    @EnvironmentObject private var environment: AppEnvironment

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                statsRow
                publishCTA
                draftsSection
                publishedSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Studio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            stat("Published", "\(environment.myPublished.count)")
            stat("Drafts",    "\(environment.myDrafts.count)")
            stat("Followers", "\(followerCount)")
        }
    }

    /// Rough indicator — the server doesn't surface the public follower count yet, so this
    /// mirrors what the user themselves follows for now. Replace with the real number once
    /// the backend exposes it.
    private var followerCount: Int { 0 }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.serif(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Primary CTA

    private var publishCTA: some View {
        Button {
            Haptics.tap()
            // Hop to Home so the full-screen editor presents on the main stack, then open it.
            environment.requestTabSwitch(.home)
            environment.pendingNewRecipe = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .bold))
                Text("Publish a new recipe")
                    .font(AppFont.body(16, weight: .bold))
                Spacer()
                Image(systemName: "arrow.forward")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(AppTheme.onBrand)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Drafts

    @ViewBuilder private var draftsSection: some View {
        let drafts = environment.myDrafts
        if !drafts.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sectionHeader("Drafts", count: drafts.count)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(drafts) { r in
                            draftCard(r)
                        }
                    }
                }
                .scrollClipDisabled()
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HorizontalScrollFrameKey.self, value: [geo.frame(in: .global)])
                })
            }
        }
    }

    private func draftCard(_ recipe: Recipe) -> some View {
        Button {
            Haptics.tap()
            environment.selectRecipe(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(width: 150, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text("Draft")
                            .font(AppFont.body(10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(8)
                    }
                Text(recipe.title)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Button {
                    Haptics.success()
                    environment.publishDraft(recipeId: recipe.id)
                } label: {
                    Text("Publish")
                        .font(AppFont.body(12, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .frame(width: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: Published

    @ViewBuilder private var publishedSection: some View {
        let pub = environment.myPublished
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("Published", count: pub.count)
            if pub.isEmpty {
                emptyPublished
            } else {
                LazyVGrid(columns: gridColumns, spacing: AppSpacing.sm) {
                    ForEach(pub) { r in publishedTile(r) }
                }
            }
        }
    }

    private var emptyPublished: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Nothing published yet")
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Tap \u{201C}Publish a new recipe\u{201D} up top. Your recipes show up on the Discover feed and your creator profile.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func publishedTile(_ recipe: Recipe) -> some View {
        Button {
            Haptics.tap()
            environment.selectRecipe(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
                Text(recipe.title)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                Button(role: .destructive) {
                    Haptics.tap()
                    environment.unpublishRecipe(recipeId: recipe.id)
                } label: {
                    Label("Move to Drafts", systemImage: "eye.slash")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(count)")
                .font(AppFont.body(13, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 2)
    }
}
