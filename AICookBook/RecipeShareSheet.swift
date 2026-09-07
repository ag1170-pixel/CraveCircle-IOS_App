//
//  RecipeShareSheet.swift
//  CraveCircle (AICookBook)
//
//  Rich sharing sheet: direct 1-tap send to Circle friends, native iOS ShareLink,
//  and quick save to Collections.
//

import SwiftUI

struct RecipeShareSheet: View {
    let recipe: Recipe
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var sentFriendIds: Set<UUID> = []
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    recipePreviewCard
                    circleFriendsSection
                    quickActionsSection
                    collectionsSection
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }
        }
    }

    // MARK: - Recipe preview

    private var recipePreviewCard: some View {
        HStack(spacing: AppSpacing.sm) {
            cover(recipe)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                CreatorLine(handle: recipe.ownerUsername)
                if let prep = recipe.prepTime {
                    Text("Prep: \(prep)")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Circle friends 1-tap send

    private var circleFriendsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Send to Circle Friends").sectionLabelStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(environment.circleFriends) { friend in
                        let isSent = sentFriendIds.contains(friend.id)
                        VStack(spacing: 6) {
                            Circle()
                                .fill(AppTheme.accentSoft)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(friend.initials)
                                        .font(AppFont.serif(18, weight: .bold))
                                        .foregroundStyle(AppTheme.accentInk)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isSent ? Color.green : AppTheme.accent, lineWidth: 2)
                                        .padding(-2)
                                )
                            Text(friend.name.split(separator: " ").first.map(String.init) ?? friend.name)
                                .font(AppFont.body(12, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Button {
                                guard !isSent else { return }
                                Haptics.success()
                                withAnimation(AppMotion.snappy) {
                                    sentFriendIds.insert(friend.id)
                                    environment.shareRecipeWithFriend(recipeId: recipe.id, friend: friend)
                                }
                            } label: {
                                Text(isSent ? "Sent ✓" : "Send")
                                    .font(AppFont.body(11, weight: .bold))
                                    .foregroundStyle(isSent ? Color.green : AppTheme.onAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(isSent ? Color.green.opacity(0.12) : AppTheme.accent, in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                        .frame(width: 72)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Quick actions (native share, copy link)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Share Outside App").sectionLabelStyle()
            VStack(spacing: 0) {
                // App-only: a cravecircle:// deep link opens the recipe in-app for anyone who has CraveCircle.
                let shareText = "\(recipe.title) on CraveCircle\ncravecircle://recipe/\(recipe.id)"
                ShareLink(item: shareText, preview: SharePreview(recipe.title, image: Image(recipe.thumbnailUrl ?? "chickenRecipe"))) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accentInk)
                            .frame(width: 28)
                        Text("Share via Messages, WhatsApp, AirDrop...")
                            .font(AppFont.body(15, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.separator).padding(.leading, 48)

                Button {
                    Haptics.tap()
                    UIPasteboard.general.string = "cravecircle://recipe/\(recipe.id)"
                    withAnimation { showCopiedAlert = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopiedAlert = false }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "link")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(showCopiedAlert ? Color.green : AppTheme.accentInk)
                            .frame(width: 28)
                        Text(showCopiedAlert ? "Link copied to clipboard!" : "Copy Recipe Link")
                            .font(AppFont.body(15, weight: .medium))
                            .foregroundStyle(showCopiedAlert ? Color.green : AppTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Save to collection

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Save to Collection").sectionLabelStyle()
            VStack(spacing: 0) {
                ForEach(Array(environment.ownedCollections.enumerated()), id: \.element.id) { index, col in
                    let isSaved = col.recipeIds.contains(recipe.id)
                    Button {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) {
                            environment.addRecipeToCollection(recipeId: recipe.id, collectionId: col.id)
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSaved ? AppTheme.accentInk : AppTheme.textTertiary)
                                .frame(width: 28)
                            Text(col.name)
                                .font(AppFont.body(15, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            if isSaved {
                                Text("Saved")
                                    .font(AppFont.body(12, weight: .bold))
                                    .foregroundStyle(AppTheme.accentInk)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if index < environment.ownedCollections.count - 1 {
                        Divider().overlay(AppTheme.separator).padding(.leading, 48)
                    }
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }
}
