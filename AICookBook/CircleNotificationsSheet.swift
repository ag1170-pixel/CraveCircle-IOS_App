//
//  CircleNotificationsSheet.swift
//  CraveCircle (AICookBook)
//
//  Circle activity and notifications sheet.
//

import SwiftUI

struct CircleNotificationsSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if environment.circleNotifications.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(environment.circleNotifications.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    Haptics.tap()
                                    environment.markNotificationRead(item.id)   // every tap responds
                                    if let recipeId = item.recipeId, !recipeId.isEmpty {
                                        dismiss()
                                        if let recipe = environment.recipes.first(where: { $0.id == recipeId }) {
                                            environment.selectRecipe(recipe)
                                        } else {
                                            environment.openRecipe(id: recipeId)   // fetch from cloud if not local
                                        }
                                    }
                                } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        Circle()
                                            .fill(AppTheme.accentSoft)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: item.symbol)
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(AppTheme.accentInk)
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(AppFont.body(15, weight: .semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text(item.message)
                                                .font(AppFont.body(13))
                                                .foregroundStyle(AppTheme.textSecondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Text(item.timeAgo)
                                                .font(AppFont.body(11))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        }
                                        Spacer()
                                        if !item.isRead {
                                            Circle()
                                                .fill(AppTheme.accent)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < environment.circleNotifications.count - 1 {
                                    Divider().overlay(AppTheme.separator).padding(.leading, 64)
                                }
                            }
                        }
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Activity & Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "bell.slash")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No activity yet")
                .font(AppFont.body(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("When friends share recipes or interact with your Circle, you'll see updates here.")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }
}
