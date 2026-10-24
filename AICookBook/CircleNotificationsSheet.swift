//
//  CircleNotificationsSheet.swift
//  CraveCircle (AICookBook)
//
//  Activity page — pushed from the home bell, Instagram-style. Rows read as a sentence
//  with the recipe thumbnail (or avatar for friend-request rows) sitting at the end. Grouped
//  into Today / Yesterday / Last 7 days / Earlier by `createdAt`; older saves without a
//  timestamp fall into Earlier.
//
//  Kept the filename for the existing callers; `CircleNotificationsSheet` is now a thin
//  alias so HomeScreen compiles while the real work lives in `CircleNotificationsScreen`.
//

import SwiftUI

typealias CircleNotificationsSheet = CircleNotificationsScreen

struct CircleNotificationsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder private var content: some View {
        let sections = buildSections()
        let incoming = environment.incomingRequests
        if sections.isEmpty && incoming.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if !incoming.isEmpty { requestsSection(incoming) }
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    // MARK: Grouped notifications

    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(section.title)
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(section.items) { item in
                    NotificationRow(item: item,
                                    recipe: recipe(for: item.recipeId),
                                    onTap: { tap(item) })
                    if item.id != section.items.last?.id {
                        Divider().overlay(AppTheme.separator).padding(.leading, 60)
                    }
                }
            }
        }
    }

    private func requestsSection(_ incoming: [FriendRequestItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Requests")
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(incoming) { item in
                    FollowRequestRow(
                        item: item,
                        onConfirm: {
                            Haptics.success()
                            withAnimation(AppMotion.snappy) {
                                environment.acceptFriendRequest(id: item.id)
                            }
                        },
                        onDelete: {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.declineFriendRequest(id: item.id)
                            }
                        }
                    )
                    if item.id != incoming.last?.id {
                        Divider().overlay(AppTheme.separator).padding(.leading, 60)
                    }
                }
            }
        }
    }

    // MARK: Interactions

    private func tap(_ item: CircleNotificationItem) {
        Haptics.tap()
        environment.markNotificationRead(item.id)
        guard let recipeId = item.recipeId, !recipeId.isEmpty else { return }
        if let recipe = environment.recipes.first(where: { $0.id == recipeId }) {
            environment.selectRecipe(recipe)
        } else {
            environment.openRecipe(id: recipeId)
        }
    }

    private func recipe(for id: String?) -> Recipe? {
        guard let id, !id.isEmpty else { return nil }
        return environment.recipes.first { $0.id == id }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
            Text("You're all caught up")
                .font(AppFont.body(17, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("When friends share recipes, follow you, or comment, it shows up here.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: Sectioning

    private struct Section: Identifiable {
        let id: String
        let title: String
        let items: [CircleNotificationItem]
    }

    private func buildSections() -> [Section] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfWeek = cal.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday

        var today: [CircleNotificationItem] = []
        var yesterday: [CircleNotificationItem] = []
        var week: [CircleNotificationItem] = []
        var earlier: [CircleNotificationItem] = []

        for item in environment.circleNotifications {
            guard let when = item.createdAt else { earlier.append(item); continue }
            if when >= startOfToday {
                today.append(item)
            } else if when >= startOfYesterday {
                yesterday.append(item)
            } else if when >= startOfWeek {
                week.append(item)
            } else {
                earlier.append(item)
            }
        }

        var sections: [Section] = []
        if !today.isEmpty     { sections.append(Section(id: "today",     title: "Today",       items: today)) }
        if !yesterday.isEmpty { sections.append(Section(id: "yesterday", title: "Yesterday",   items: yesterday)) }
        if !week.isEmpty      { sections.append(Section(id: "week",      title: "Last 7 days", items: week)) }
        if !earlier.isEmpty   { sections.append(Section(id: "earlier",   title: "Earlier",     items: earlier)) }
        return sections
    }
}

// MARK: - Rows

private struct NotificationRow: View {
    let item: CircleNotificationItem
    let recipe: Recipe?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text(item.title).font(AppFont.body(14, weight: .bold)) +
                        Text("  ") +
                        Text(item.message).font(AppFont.body(14))
                    )
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    Text(item.timeAgo)
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer(minLength: 4)
                trailingThumbnail
                if !item.isRead {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 7, height: 7)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var leading: some View {
        ZStack {
            Circle().fill(AppTheme.accentSoft)
                .frame(width: 44, height: 44)
            Image(systemName: item.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
        }
    }

    @ViewBuilder private var trailingThumbnail: some View {
        if let recipe {
            RecipeCoverImage(recipe: recipe)
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }
}

private struct FollowRequestRow: View {
    let item: FriendRequestItem
    let onConfirm: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(AppTheme.accentSoft).frame(width: 44, height: 44)
                .overlay(
                    Text(item.initials)
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                )
            VStack(alignment: .leading, spacing: 2) {
                (
                    Text(item.username).font(AppFont.body(14, weight: .bold)) +
                    Text("  requested to follow you.")
                        .font(AppFont.body(14))
                )
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                Text(item.name)
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Button(action: onConfirm) {
                    Text("Confirm")
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                Button(action: onDelete) {
                    Text("Delete")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }
}
