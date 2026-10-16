//
//  NutritionScreen.swift
//  CraveCircle (AICookBook)
//
//  Per-serving numbers, shown so the calorie count is read first and each macro
//  is one row: grams, share of this meal, and percent of the daily value.
//

import SwiftUI

struct NutritionScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @State private var openMacro: MacroKind?

    private var nutrition: RecipeNutrition { recipe.nutritionOrEstimate }

    private let proteinColor = Color(hex: "E0A02E")
    private let carbsColor = Color(hex: "E25B4C")
    private let fatColor = Color(hex: "4C8FE8")

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    dish
                    calories
                    macros
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .leadingEdgeBack { dismiss() }
    }

    private var topBar: some View {
        ZStack {
            Text("Nutrition")
                .font(AppFont.body(17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var dish: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            RecipeCoverImage(recipe: recipe)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(dishLine)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var dishLine: String {
        var parts = ["\(max(recipe.servings ?? 1, 1)) servings"]
        if let cook = recipe.totalTimeText { parts.append("\(cook) cook") }
        return parts.joined(separator: " · ")
    }

    private var calories: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(nutrition.calories.rounded()))")
                .font(AppFont.display(64, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(nutrition.estimated ? "kcal per serving · Estimated" : "kcal per serving")
                .font(AppFont.body(15, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var macros: some View {
        VStack(spacing: 0) {
            macroRow(.protein, grams: nutrition.proteinG, meal: nutrition.proteinPercent,
                     reference: RecipeNutrition.proteinDailyG, color: proteinColor)
            Divider().overlay(AppTheme.separator).padding(.leading, 22)
            macroRow(.carbs, grams: nutrition.carbsG, meal: nutrition.carbsPercent,
                     reference: RecipeNutrition.carbsDailyG, color: carbsColor)
            Divider().overlay(AppTheme.separator).padding(.leading, 22)
            macroRow(.fat, grams: nutrition.fatG, meal: nutrition.fatPercent,
                     reference: RecipeNutrition.fatDailyG, color: fatColor)
        }
        .padding(.vertical, 4)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func macroRow(_ kind: MacroKind, grams: Double, meal: Int, reference: Double, color: Color) -> some View {
        let gramsShown = Int(grams.rounded())
        let daily = RecipeNutrition.dailyValuePercent(grams: Double(gramsShown), reference: reference)
        let sources = nutrition.contributions(for: kind)
        let open = openMacro == kind
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                guard !sources.isEmpty else { return }
                Haptics.tap()
                withAnimation(AppMotion.snappy) { openMacro = open ? nil : kind }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(kind.title)
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if !sources.isEmpty {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                        Spacer(minLength: 8)
                        Text("\(gramsShown) g")
                            .font(AppFont.body(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Text("\(meal)% of this meal · \(daily)% daily")
                        .font(AppFont.body(13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.leading, 16)
                    shareBar(percent: meal, color: color)
                        .padding(.leading, 16)
                }
            }
            .buttonStyle(.plain)
            .disabled(sources.isEmpty)
            .accessibilityLabel("\(kind.title), \(gramsShown) grams, \(meal) percent of this meal, \(daily) percent of the daily value")
            if open {
                ForEach(sources, id: \.item.name) { row in
                    HStack {
                        Text(row.item.name)
                            .font(AppFont.body(13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(row.item.value(for: kind).rounded())) g")
                            .font(AppFont.body(13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 14)
    }

    private func shareBar(percent: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(Double(percent) / 100, 1))
            }
        }
        .frame(height: 5)
    }
}
