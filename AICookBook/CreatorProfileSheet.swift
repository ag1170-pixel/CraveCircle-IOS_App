//
//  CreatorProfileSheet.swift
//  CraveCircle (AICookBook)
//
//  Creator profile sheet and their recipe catalog.
//

import SwiftUI

struct CreatorProfileSheet: View {
    let handle: String
    let name: String?
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile?

    private var cleanHandle: String {
        handle.hasPrefix("@") ? handle : "@\(handle)"
    }

    private var initials: String {
        if let name, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
        }
        let clean = cleanHandle.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
    }

    private var creatorRecipes: [Recipe] {
        environment.recipes.filter {
            ($0.ownerUsername?.lowercased() == cleanHandle.lowercased()) ||
            ($0.ownerUsername?.lowercased() == cleanHandle.replacingOccurrences(of: "@", with: "").lowercased())
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    headerSection
                    if let bio = profile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                    }
                    socialsSection
                    statsSection
                    recipesSection
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }
            .task { profile = await environment.fetchPublicProfile(username: cleanHandle) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(AppTheme.accentSoft)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(initials)
                        .font(AppFont.serif(28, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                )
                .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2).padding(-3))

            VStack(spacing: 2) {
                Text(name ?? cleanHandle.replacingOccurrences(of: "@", with: "").capitalized)
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 4) {
                    Text(cleanHandle)
                        .font(AppFont.body(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    // Blue tick only shows for admin-verified accounts, not everyone.
                    if profile?.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.blue)
                    }
                }
            }

            followButton
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    /// Hidden when the viewer IS the creator (you don't follow yourself).
    @ViewBuilder private var followButton: some View {
        let me = environment.currentUser?.username?.lowercased() ?? ""
        let his = cleanHandle.replacingOccurrences(of: "@", with: "").lowercased()
        let mineAt = me.hasPrefix("@") ? me : "@" + me
        if his != me && his != mineAt.replacingOccurrences(of: "@", with: "") {
            let on = environment.isFollowing(creatorHandle: cleanHandle)
            FollowPill(isFollowing: on) {
                Haptics.tap()
                environment.toggleFollow(creatorHandle: cleanHandle)
            }
        }
    }

    // MARK: - Socials row

    /// First 4 populated social links as tappable chips. Anything beyond collapses into a
    /// chevron Menu so the row stays single-line even if the creator has 5 platforms. Fixed
    /// order (IG, TikTok, YT, Pinterest, FB) — no drag-drop; at 5 total it isn't worth it.
    @ViewBuilder private var socialsSection: some View {
        let links: [(String, String, String)] = [    // (platform, systemImage, url)
            ("Instagram", "camera.fill",         profile?.instagramUrl ?? ""),
            ("TikTok",    "music.note",          profile?.tiktokUrl    ?? ""),
            ("YouTube",   "play.rectangle.fill", profile?.youtubeUrl   ?? ""),
            ("Pinterest", "pin.fill",            profile?.pinterestUrl ?? ""),
            ("Facebook",  "person.2.fill",       profile?.facebookUrl  ?? ""),
        ].filter { !$0.2.isEmpty }

        if !links.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(links.prefix(4)), id: \.0) { label, icon, urlStr in
                    socialChip(label: label, icon: icon, urlStr: urlStr)
                }
                if links.count > 4 {
                    Menu {
                        ForEach(links.dropFirst(4), id: \.0) { label, _, urlStr in
                            Link(label, destination: URL(string: urlStr) ?? URL(string: "about:blank")!)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 42, height: 36)
                            .background(AppTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func socialChip(label: String, icon: String, urlStr: String) -> some View {
        Link(destination: URL(string: urlStr) ?? URL(string: "about:blank")!) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(AppFont.body(12, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: AppSpacing.sm) {
            statCard("Recipes", "\(creatorRecipes.count)")
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.serif(20, weight: .bold))
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

    // MARK: - Recipes Grid

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Recipes").sectionLabelStyle()
            if creatorRecipes.isEmpty {
                Text("No published recipes found.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, AppSpacing.md)
            } else {
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(creatorRecipes) { recipe in
                        LibraryCard(recipe: recipe) {
                            dismiss()
                            environment.selectRecipe(recipe)
                        }
                    }
                }
            }
        }
    }
}
