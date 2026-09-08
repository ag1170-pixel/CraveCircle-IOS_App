//
//  StudioScreen.swift
//  CraveCircle (AICookBook)
//
//  Creator Studio — matched to the web `creator` page: publish recipes to your Circle.
//  Stats (Followers / Recipes / Saves / Views), Drafts | Published tabs, a recipe grid
//  with Edit/Publish, and a "From your library" promote strip. Light/cream + coral + serif.
//

import SwiftUI

struct StudioScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var tab = 0   // 0 = Drafts, 1 = Published
    @State private var editingRecipe: Recipe?
    @State private var showNewRecipe = false
    @State private var showCreatorRequest = false

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    private var drafts: [Recipe] {
        environment.myDrafts        // your own draft recipes (owner-aware)
    }

    private var published: [Recipe] {
        environment.myPublished     // your own published recipes (owner-aware)
    }

    private var shownRecipes: [Recipe] { tab == 0 ? drafts : published }

    var body: some View {
        NavigationStack {
            if environment.isGuest {
                GuestWallView(
                    title: "Creator Studio",
                    message: "Log in to open your Creator Studio and publish recipes to your Circle."
                )
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    header
                    if environment.canPublish {
                        statsGrid
                        LimeSegmentedControl(
                            segments: ["Drafts \(drafts.count)", "Published \(published.count)"],
                            selection: $tab
                        )
                        recipeGrid
                        libraryStrip
                    } else {
                        enrollCard
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, 120)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .fullScreenCover(item: $editingRecipe) { recipe in
                RecipeEditScreen(
                    recipe: Binding(
                        get: { recipe },
                        set: { updated in
                            editingRecipe = updated
                            environment.updateRecipe(updated)
                        }
                    ),
                    onSave: { environment.updateRecipe($0) }
                )
                .environmentObject(environment)
            }
            .fullScreenCover(isPresented: $showNewRecipe) {
                newRecipeEditor
            }
            .sheet(isPresented: $showCreatorRequest) {
                CreatorRequestSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                if environment.recipes.isEmpty { await environment.refreshRecipes() }
                if !environment.canPublish { await environment.loadMyCreatorRequestStatus() }
            } // Close task
            } // Close else
        } // Close NavigationStack
        .tint(AppTheme.accentInk)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Studio")
                    .font(AppFont.display(30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Publish recipes to your Circle")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if environment.canPublish {
                PillButton(title: "New", systemImage: "plus", kind: .filled) {
                    Haptics.tap()
                    showNewRecipe = true
                }
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    // MARK: Stats

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            StatCard(label: "Followers", value: "2.4k")
            StatCard(label: "Published", value: "\(published.count)")
            StatCard(label: "Total saves", value: short(published.count * 340 + 120))
            StatCard(label: "Total views", value: short(published.count * 1820 + 540))
        }
    }

    // MARK: Recipe grid

    @ViewBuilder private var recipeGrid: some View {
        if shownRecipes.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                ForEach(shownRecipes) { recipe in
                    StudioRecipeCard(
                        recipe: recipe,
                        isDraft: tab == 0,
                        onOpen: { environment.selectRecipe(recipe) },
                        onEdit: { editingRecipe = recipe },
                        onPublish: {
                            Haptics.success()
                            withAnimation(AppMotion.snappy) {
                                environment.publishDraft(recipeId: recipe.id)
                            }
                        },
                        onUnpublish: {
                            Haptics.tap()
                            withAnimation(AppMotion.snappy) {
                                environment.unpublishRecipe(recipeId: recipe.id)
                            }
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
            Text(tab == 0 ? "No drafts yet" : "No published recipes yet")
                .font(AppFont.body(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(tab == 0
                 ? "Create a recipe or promote one from your library."
                 : "Publish a draft to make it live on your profile.")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: From your library

    @ViewBuilder private var libraryStrip: some View {
        if !environment.recipes.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("From your library")
                        .font(AppFont.display(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text("Publish recipes you already created — no need to start from scratch.")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        ForEach(environment.ownedRecipes) { recipe in
                            LibraryPromoteCard(recipe: recipe) {
                                Haptics.success()
                                withAnimation(AppMotion.snappy) {
                                    environment.promoteToStudio(recipe: recipe)
                                    tab = 0
                                }
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var enrollCard: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentInk)
            }
            .padding(.top, AppSpacing.sm)

            VStack(spacing: 6) {
                Text("CraveCircle Creator Studio")
                    .font(AppFont.serif(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Publish recipes directly to the Circle, curate your culinary drafts, and build your food community.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.sm)
            }

            VStack(alignment: .leading, spacing: 12) {
                enrollBenefit(icon: "pencil.and.list.clipboard", title: "Author & Edit Recipes", subtitle: "Full control over ingredients, instructions, and servings.")
                enrollBenefit(icon: "arrow.up.circle.fill", title: "Publish to Circle", subtitle: "Share your culinary creations with food lovers worldwide.")
                enrollBenefit(icon: "chart.line.uptrend.xyaxis", title: "Creator Insights", subtitle: "Track saves, likes, and engagement on your recipes.")
            }
            .padding(AppSpacing.md)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            if environment.hasPendingCreatorRequest {
                PillButton(title: "Request under review", systemImage: "clock", kind: .filled) { }
                    .disabled(true)
                    .padding(.top, AppSpacing.xs)
                Text("An admin is verifying your social profile. You'll be able to publish once approved.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
            } else {
                PillButton(title: "Become a Creator", systemImage: "sparkles", kind: .filled) {
                    Haptics.tap()
                    if environment.hasRealSession {
                        showCreatorRequest = true          // request → admin approval
                    } else {
                        withAnimation(AppMotion.snappy) { environment.enrollInStudio() }  // dev/no-auth fallback
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card * 1.5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card * 1.5, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }

    private func enrollBenefit(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var newRecipeEditor: some View {
        var blank = Recipe(
            id: "draft-\(UUID().uuidString.prefix(8))",
            ownerId: environment.currentUser?.id ?? "preview-user",
            title: "New Culinary Creation",
            description: "Describe your dish, inspiration, and flavors.",
            prepTime: "15 min",
            cookTime: "20 min",
            servings: 2,
            ingredients: [
                IngredientGroup(groupName: "Main Ingredients", items: ["2 tbsp olive oil", "1 pinch sea salt"])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Prep ingredients and heat pan.")
            ],
            thumbnailUrl: nil,
            ownerUsername: environment.currentUser?.username ?? "@aicookbook"
        )
        return RecipeEditScreen(
            recipe: Binding(
                get: { blank },
                set: { blank = $0 }
            ),
            onSave: { newRecipe in
                environment.addCustomGroceryItem(name: "")
                environment.updateRecipe(newRecipe)
                environment.promoteToStudio(recipe: newRecipe)
                showNewRecipe = false
            }
        )
        .environmentObject(environment)
    }

    private func short(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}

// MARK: - Stat card

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(AppFont.label(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(AppFont.serif(28, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}

// MARK: - Studio recipe card (status chip + context actions)

struct StudioRecipeCard: View {
    let recipe: Recipe
    let isDraft: Bool
    let onOpen: () -> Void
    var onEdit: (() -> Void)? = nil
    let onPublish: () -> Void
    var onUnpublish: (() -> Void)? = nil

    var body: some View {
        Button {
            Haptics.tap(); onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                cover(recipe)
                    .aspectRatio(1.1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay(alignment: .topLeading) { statusChip.padding(8) }
                Text(recipe.title)
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if isDraft {
                    PillButton(title: "Publish", systemImage: "arrow.up.circle.fill", kind: .filled) { onPublish() }
                        .font(AppFont.body(13, weight: .bold))
                } else {
                    Text("Live on your profile")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button { (onEdit ?? onOpen)() } label: { Label("Edit", systemImage: "pencil") }
            if isDraft {
                Button { onPublish() } label: { Label("Publish to Circle", systemImage: "arrow.up.circle") }
            } else {
                Button { onUnpublish?() } label: { Label("Move to Drafts", systemImage: "arrow.down.circle") }
            }
        }
    }

    private var statusChip: some View {
        HStack(spacing: 4) {
            Image(systemName: isDraft ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isDraft ? "Draft" : "Published")
                .font(AppFont.body(11, weight: .bold))
        }
        .foregroundStyle(isDraft ? AppTheme.textPrimary : AppTheme.onAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isDraft ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppTheme.accent), in: Capsule())
    }
}

// MARK: - Library promote card

struct LibraryPromoteCard: View {
    let recipe: Recipe
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover(recipe)
                .frame(width: 150, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
            Text(recipe.title)
                .font(AppFont.body(14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Button {
                Haptics.tap(); onAdd()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.circle").font(.system(size: 13, weight: .bold))
                    Text("Add to studio").font(AppFont.body(13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accentInk)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 150, alignment: .leading)
    }
}
