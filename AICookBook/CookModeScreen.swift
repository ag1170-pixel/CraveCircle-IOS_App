//
//  CookModeScreen.swift
//  CraveCircle (AICookBook)
//
//  Cook Mode — the at-the-stove checklist. Kitchen ergonomics: large tap targets,
//  glanceable progress, forgiving of wet hands and divided attention. Full-screen,
//  dark-first. Ingredients + Steps in one place; check as you go.
//

import SwiftUI

struct CookModeScreen: View {
    let recipe: Recipe
    let servings: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var checkedIngredients: Set<String>
    @State private var checkedSteps: Set<Int>
    @State private var showFlashcards = false

    init(recipe: Recipe, servings: Int? = nil, demoIngredients: Set<String> = [], demoSteps: Set<Int> = []) {
        self.recipe = recipe
        self.servings = servings ?? (recipe.servings ?? 2)
        _checkedIngredients = State(initialValue: demoIngredients)
        _checkedSteps = State(initialValue: demoSteps)
    }

    private var ingredientKeys: [(key: String, text: String)] {
        let base = recipe.servings ?? 2
        return recipe.ingredients.enumerated().flatMap { g, group in
            group.items.enumerated().map { i, item in
                let scaled = IngredientScaler.scale(text: item, from: base, to: servings)
                return ("\(g):\(i)", scaled)
            }
        }
    }
    private var steps: [DirectionStep] { recipe.directions.sorted { $0.stepIndex < $1.stepIndex } }
    private var total: Int { ingredientKeys.count + steps.count }
    private var done: Int { checkedIngredients.count + checkedSteps.count }
    private var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    section("Ingredients") {
                        ForEach(Array(ingredientKeys.enumerated()), id: \.offset) { idx, pair in
                            CookRow(text: pair.text, checked: checkedIngredients.contains(pair.key)) {
                                toggle(&checkedIngredients, pair.key)
                            }
                            if idx < ingredientKeys.count - 1 { rowDivider }
                        }
                    }
                    section("Steps") {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            CookRow(number: idx + 1, text: step.text, checked: checkedSteps.contains(step.stepIndex)) {
                                toggle(&checkedSteps, step.stepIndex)
                            }
                            if idx < steps.count - 1 { rowDivider }
                        }
                    }
                    resetNote
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: Header with progress

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                Text("Cook Mode").sectionLabelStyle(AppTheme.accentInk)
                Spacer()
                Button {
                    Haptics.tap(); showFlashcards = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill").font(.system(size: 12, weight: .bold))
                        Text("Flashcards").font(AppFont.body(13, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                Button {
                    Haptics.tap(); dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            .fullScreenCover(isPresented: $showFlashcards) {
                FlashcardCookScreen(recipe: recipe)
            }

            Text(recipe.title)
                .font(AppFont.display(26, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline) {
                Text("\(done) of \(total) done")
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .contentTransition(.numericText())
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(AppFont.mono(15, weight: .bold))
                    .foregroundStyle(AppTheme.accentInk)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.surface)
                    Capsule().fill(AppTheme.accent)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 10)
            .animation(reduceMotion ? nil : AppMotion.smooth, value: progress)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.md)
        .background(
            AppTheme.background
                .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.separator).frame(height: 1) }
        )
    }

    // MARK: Sections

    private func section(_ title: String, @ViewBuilder _ rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).sectionLabelStyle().padding(.bottom, AppSpacing.xs)
            VStack(spacing: 0) { rows() }
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(AppTheme.separator).frame(height: 1).padding(.leading, 44)
    }

    private var resetNote: some View {
        Label("Checklist resets daily at midnight", systemImage: "clock.arrow.circlepath")
            .font(AppFont.body(13))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.sm)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        let willCheck = !set.contains(value)
        Haptics.toggle(willCheck)
        if willCheck { set.insert(value) } else { set.remove(value) }
    }
}

// MARK: - Large cook row (kitchen tap target)

private struct CookRow: View {
    var number: Int? = nil
    let text: String
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(checked ? AppTheme.accent : Color.clear)
                        .frame(width: 30, height: 30)
                    Circle()
                        .strokeBorder(checked ? Color.clear : AppTheme.textTertiary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    if checked {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.onAccent)
                    }
                }

                if let number {
                    Text(String(format: "%02d", number))
                        .font(AppFont.mono(15, weight: .bold))
                        .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                }

                Text(text)
                    .font(AppFont.body(18, weight: .medium))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 16)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CookModeScreen(recipe: Recipe.placeholderRecipes[0])
}
