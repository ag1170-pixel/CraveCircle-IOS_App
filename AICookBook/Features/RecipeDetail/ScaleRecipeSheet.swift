//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: ScaleRecipeSheet.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Modal presentation sheet for ScaleRecipeSheet.
//
// 2. ARCHITECTURAL ROLE:
//    Provides focused modal user interactions, form inputs, and state updates.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "ScaleRecipeSheet is presented modally to capture user input and update shared application state."
//
// ==============================================================================
//

//
//  ScaleRecipeSheet.swift
//  CraveCircle (AICookBook)
//
//  Modal sheet allowing the cook to dynamically scale recipe servings,
//  preview scaled ingredients in real-time, and apply to the recipe.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct ScaleRecipeSheet: View {
    let recipe: Recipe
    @Binding var servings: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedServings: Int

    private var baseServings: Int {
        max(1, recipe.servings ?? 2)
    }

    private var multiplier: Double {
        Double(selectedServings) / Double(baseServings)
    }

    init(recipe: Recipe, servings: Binding<Int>) {
        self.recipe = recipe
        self._servings = servings
        self._selectedServings = State(initialValue: servings.wrappedValue)
    }

    private let presetMultipliers: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    servingsCard
                    presetsRow
                    ingredientsPreviewCard
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 100) // Clear bottom pinned button
            }
            .scrollIndicators(.hidden)
            .background(AppScreenBackground())
            .navigationTitle("Scale Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surfaceElevated, in: Circle())
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.8))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if selectedServings != baseServings {
                        Button {
                            Haptics.tap()
                            withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                                selectedServings = baseServings
                            }
                        } label: {
                            Text("Reset")
                                .font(AppFont.body(13, weight: .bold))
                                .foregroundStyle(AppTheme.brand)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.brand.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .overlay(alignment: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: - Servings Stepper Card

    private var servingsCard: some View {
        VStack(spacing: 14) {
            Text("Adjust Servings")
                .font(AppFont.body(13, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 24) {
                Button {
                    if selectedServings > 1 {
                        Haptics.tap()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            selectedServings -= 1
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(selectedServings > 1 ? AppTheme.accentInk : AppTheme.textTertiary)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(selectedServings <= 1)
                .accessibilityLabel("Decrease servings")

                VStack(spacing: 3) {
                    Text("\(selectedServings)")
                        .font(AppFont.display(36, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(selectedServings == 1 ? "Serving" : "Servings")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(minWidth: 110)

                Button {
                    if selectedServings < 30 {
                        Haptics.tap()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            selectedServings += 1
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.accentInk)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(selectedServings >= 30)
                .accessibilityLabel("Increase servings")
            }

            // Ratio badge
            HStack(spacing: 6) {
                if selectedServings == baseServings {
                    Text("Original size (\(baseServings) \(baseServings == 1 ? "serving" : "servings"))")
                        .font(AppFont.body(12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    let formatted = formatMultiplier(multiplier)
                    Text("\(formatted)× Original")
                        .font(AppFont.body(12, weight: .bold))
                        .foregroundStyle(AppTheme.brand)

                    Text("· Original was \(baseServings)")
                        .font(AppFont.body(12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(AppTheme.accentSoft.opacity(0.6), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Multiplier Presets Row

    private var presetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presetMultipliers, id: \.self) { mult in
                    let target = max(1, Int(round(Double(baseServings) * mult)))
                    let isSelected = selectedServings == target
                    Button {
                        Haptics.select()
                        withAnimation(reduceMotion ? .none : AppMotion.snappy) {
                            selectedServings = target
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(formatMultiplier(mult) + "×")
                                .font(AppFont.body(13, weight: .bold))
                            if mult == 1.0 {
                                Text("(Orig)")
                                    .font(AppFont.body(11, weight: .medium))
                            }
                        }
                        .foregroundStyle(isSelected ? AppTheme.onBrand : AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? AnyShapeStyle(AppTheme.brand) : AnyShapeStyle(AppTheme.surface),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? Color.clear : AppTheme.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Ingredients Preview Card

    private var ingredientsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scaled Ingredients")
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                let totalCount = recipe.ingredients.flatMap(\.items).count
                Text("\(totalCount) items")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 1)

            let groups = recipe.ingredients
            if groups.isEmpty || groups.allSatisfy({ $0.items.isEmpty }) {
                Text("No ingredients listed for this recipe.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(groups.enumerated()), id: \.offset) { gIdx, group in
                    VStack(alignment: .leading, spacing: 10) {
                        if let name = group.groupName, !name.isEmpty {
                            Text(name)
                                .font(AppFont.label(12, weight: .bold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.top, gIdx > 0 ? 6 : 0)
                        }

                        ForEach(Array(group.items.enumerated()), id: \.offset) { iIdx, item in
                            let scaled = IngredientListFormat.scaledLine(item, from: baseServings, to: selectedServings)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(AppTheme.brand)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scaled)
                                            .font(AppFont.body(15, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if selectedServings != baseServings && scaled != item {
                                            Text("Originally: \(item)")
                                                .font(AppFont.body(12))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }

                                if iIdx < group.items.count - 1 {
                                    Rectangle()
                                        .fill(AppTheme.separator)
                                        .frame(height: 1)
                                        .padding(.leading, 16)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: - Bottom Pinned Action Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.hairline)

            Button {
                Haptics.success()
                servings = selectedServings
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Apply to Recipe (\(selectedServings) \(selectedServings == 1 ? "Serving" : "Servings"))")
                        .font(AppFont.body(16, weight: .bold))
                }
                .foregroundStyle(AppTheme.onBrand)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.brand, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(AppTheme.surface.ignoresSafeArea())
        }
    }

    private func formatMultiplier(_ val: Double) -> String {
        if val == Double(Int(val)) {
            return "\(Int(val))"
        } else {
            return String(format: "%.1f", val)
        }
    }
}

