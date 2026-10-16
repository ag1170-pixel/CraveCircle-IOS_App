//
//  NutritionScreen.swift
//  CraveCircle (AICookBook)
//
//  Same per-serving numbers the recipe already stores. This page only shows them.
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
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    header
                    donutCard
                    macrosCard
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
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

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            RecipeCoverImage(recipe: recipe)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(AppFont.body(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        var parts = ["\(max(recipe.servings ?? 1, 1)) servings"]
        if let cook = recipe.totalTimeText { parts.append("\(cook) cook") }
        if nutrition.estimated { parts.append("Estimated") }
        return parts.joined(separator: " · ")
    }

    private var donutCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            ZStack {
                MealDonut(protein: nutrition.proteinG, carbs: nutrition.carbsG, fat: nutrition.fatG,
                          proteinColor: proteinColor, carbsColor: carbsColor, fatColor: fatColor)
                    .frame(width: 148, height: 148)
                VStack(spacing: 0) {
                    Text("\(Int(nutrition.calories.rounded()))")
                        .font(AppFont.display(32, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                    Text("kcal")
                        .font(AppFont.body(13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                legendRow("Protein", grams: nutrition.proteinG, percent: nutrition.proteinPercent, color: proteinColor)
                legendRow("Carbs", grams: nutrition.carbsG, percent: nutrition.carbsPercent, color: carbsColor)
                legendRow("Fat", grams: nutrition.fatG, percent: nutrition.fatPercent, color: fatColor)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(NutritionPanel())
    }

    private func legendRow(_ name: String, grams: Double, percent: Int, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(shownGrams(grams)) g · \(percent)%")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Macronutrients")
                    .font(AppFont.body(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("% Daily Value")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            macroRow(.protein, grams: nutrition.proteinG, reference: RecipeNutrition.proteinDailyG, color: proteinColor)
            macroRow(.carbs, grams: nutrition.carbsG, reference: RecipeNutrition.carbsDailyG, color: carbsColor)
            macroRow(.fat, grams: nutrition.fatG, reference: RecipeNutrition.fatDailyG, color: fatColor)
        }
        .padding(AppSpacing.md)
        .modifier(NutritionPanel())
    }

    private func macroRow(_ kind: MacroKind, grams: Double, reference: Double, color: Color) -> some View {
        let gramsShown = shownGrams(grams)
        let dv = RecipeNutrition.dailyValuePercent(grams: Double(gramsShown), reference: reference)
        let open = openMacro == kind
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) { openMacro = open ? nil : kind }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(kind.title)
                        .font(AppFont.body(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    dvBar(percent: dv, color: color)
                    Text("\(gramsShown) g")
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                    Text("\(dv)%")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if open {
                contributionList(kind)
            }
        }
    }

    private func dvBar(percent: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(Double(percent) / 100, 1))
            }
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func contributionList(_ kind: MacroKind) -> some View {
        let rows = nutrition.contributions(for: kind)
        if rows.isEmpty {
            Text("No ingredient sources for this.")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textTertiary)
        } else {
            ForEach(rows, id: \.item.name) { row in
                HStack {
                    Text(row.item.name)
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(shownGrams(row.item.value(for: kind))) g · \(row.percent)%")
                        .font(AppFont.body(12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
    }

    private func shownGrams(_ grams: Double) -> Int { Int(grams.rounded()) }
}

private struct MealDonut: View {
    var protein: Double
    var carbs: Double
    var fat: Double
    var proteinColor: Color
    var carbsColor: Color
    var fatColor: Color

    var body: some View {
        let proteinK = max(protein, 0) * 4
        let carbsK = max(carbs, 0) * 4
        let fatK = max(fat, 0) * 9
        let total = max(proteinK + carbsK + fatK, 1)
        let p = proteinK / total
        let c = carbsK / total
        let gap = 0.015
        ZStack {
            arc(from: gap, to: max(p - gap, gap), color: proteinColor)
            arc(from: p + gap, to: max(p + c - gap, p + gap), color: carbsColor)
            arc(from: p + c + gap, to: max(1 - gap, p + c + gap), color: fatColor)
        }
        .rotationEffect(.degrees(-90))
    }

    private func arc(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from, to: max(to, from))
            .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
    }
}

private struct NutritionPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}
