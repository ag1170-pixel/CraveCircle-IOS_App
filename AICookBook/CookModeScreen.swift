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
                let scaled = IngredientListFormat.scaledLine(item, from: base, to: servings)
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
            List {
                Section("Ingredients") {
                    ForEach(ingredientKeys, id: \.key) { pair in
                        ChecklistRow(title: ingredientLine(pair.text, size: 17), minHeight: 56, checkLeading: true, checked: checkedIngredients.contains(pair.key)) {
                            toggleChecklistItem(&checkedIngredients, pair.key)
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                }
                Section {
                    ForEach(Array(steps.enumerated()), id: \.element.stepIndex) { index, step in
                        ChecklistRow(
                            title: AttributedString("\(index + 1). \(step.text)"),
                            minHeight: 56,
                            checked: checkedSteps.contains(step.stepIndex)
                        ) {
                            toggleChecklistItem(&checkedSteps, step.stepIndex)
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    resetNote
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .tint(AppTheme.accentInk)
        .leadingEdgeBack { dismiss() }
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
                .accessibilityLabel("Exit Cook Mode")
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

    private var resetNote: some View {
        Label("Checklist resets daily at midnight", systemImage: "clock.arrow.circlepath")
            .font(AppFont.body(13))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.sm)
    }
}

#Preview {
    CookModeScreen(recipe: Recipe.placeholderRecipes[0])
}
