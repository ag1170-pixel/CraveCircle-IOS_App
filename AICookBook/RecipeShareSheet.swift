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
    @State private var usernameToShare = ""
    @State private var usernameShareStatus: String?   // nil / sending / sent / notfound

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    recipePreviewCard
                    usernameShareSection
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

    // MARK: - Send to a CraveCircle user (by @username — any user, no creator role needed)

    private var usernameShareSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Send to a CraveCircle User").sectionLabelStyle()
            HStack(spacing: AppSpacing.xs) {
                HStack(spacing: 4) {
                    Text("@").foregroundStyle(AppTheme.textTertiary)
                    TextField("username", text: $usernameToShare)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(AppTheme.textPrimary)
                        .onChange(of: usernameToShare) { _, _ in usernameShareStatus = nil }
                }
                .font(AppFont.body(16))
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 46)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))

                Button { sendToUsername() } label: {
                    Group {
                        if usernameShareStatus == "sending" { ProgressView().tint(AppTheme.onAccent) }
                        else { Image(systemName: usernameShareStatus == "sent" ? "checkmark" : "paperplane.fill") }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(usernameToShare.trimmingCharacters(in: .whitespaces).isEmpty || usernameShareStatus == "sending")
                .accessibilityLabel("Send to user")
            }
            if usernameShareStatus == "sent" {
                Text("Sent — they'll see it in their Shared inbox.")
                    .font(AppFont.body(12)).foregroundStyle(AppTheme.accent)
            } else if usernameShareStatus == "notfound" {
                Text("No CraveCircle user with that username (they need an account).")
                    .font(AppFont.body(12)).foregroundStyle(AppTheme.destructive)
            }
        }
    }

    private func sendToUsername() {
        let handle = usernameToShare.trimmingCharacters(in: .whitespaces)
        guard !handle.isEmpty else { return }
        usernameShareStatus = "sending"
        Task {
            let ok = await environment.shareRecipeToUsername(recipeId: recipe.id, username: handle)
            await MainActor.run {
                usernameShareStatus = ok ? "sent" : "notfound"
                if ok { Haptics.success(); usernameToShare = "" }
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
                if let cook = recipe.cookTime, !cook.isEmpty {
                    Text(cook)
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
                // Web-friendly link: an https link ensures messaging apps render it clickable.
                let shareText = "\(recipe.title) on CraveCircle\nhttps://cravecircle.cc/recipe/\(recipe.id)"
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
                    UIPasteboard.general.string = "https://cravecircle.cc/recipe/\(recipe.id)"
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
