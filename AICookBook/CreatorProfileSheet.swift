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
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }

        }
        .frame(maxWidth: .infinity)
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
