//
//  NutritionScreen.swift
//  CraveCircle (AICookBook)
//
//  The recipe page opens this instead of an inline nutrition card.
//  Per serving is the stored value. Whole recipe multiplies by the batch the user set.
//

import SwiftUI

struct NutritionScreen: View {
    let recipe: Recipe
    let servings: Int

    @Environment(\.dismiss) private var dismiss
    @State private var whole = 0
    @State private var openMacro: MacroKind?

    private var nutrition: RecipeNutrition { recipe.nutritionOrEstimate }
    private var isWhole: Bool { whole == 1 }
    private var scale: Double { RecipeNutrition.portionMultiplier(servings: servings, whole: isWhole) }

    private var proteinG: Double { nutrition.proteinG * scale }
    private var carbsG: Double { nutrition.carbsG * scale }
    private var fatG: Double { nutrition.fatG * scale }
    private var calories: Double { nutrition.calories * scale }

    private let proteinColor = Color(hex: "E0A02E")
    private let carbsColor = Color(hex: "E25B4C")
    private let fatColor = Color(hex: "4C8FE8")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    header
                    LimeSegmentedControl(segments: ["Per serving", "Whole recipe"], selection: $whole)
                    donutCard
                    macrosCard
                    breakdownCard
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .tint(AppTheme.accentInk)
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
        var parts = ["\(max(servings, 1)) servings"]
        if let cook = recipe.totalTimeText { parts.append("\(cook) cook") }
        if nutrition.estimated { parts.append("Estimated") }
        return parts.joined(separator: " · ")
    }

    private var donutCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.lg) {
            ZStack {
                MealDonut(protein: proteinG, carbs: carbsG, fat: fatG,
                          proteinColor: proteinColor, carbsColor: carbsColor, fatColor: fatColor)
                    .frame(width: 148, height: 148)
                VStack(spacing: 0) {
                    Text("\(Int(calories.rounded()))")
                        .font(AppFont.display(32, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(AppFont.body(13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                legendRow("Protein", grams: proteinG, percent: nutrition.proteinPercent, color: proteinColor)
                legendRow("Carbs", grams: carbsG, percent: nutrition.carbsPercent, color: carbsColor)
                legendRow("Fat", grams: fatG, percent: nutrition.fatPercent, color: fatColor)
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
                Text("\(Int(grams.rounded())) g · \(percent)%")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
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
            }
            macroRow(.protein, grams: proteinG, dv: RecipeNutrition.dailyValuePercent(grams: proteinG, reference: RecipeNutrition.proteinDailyG), color: proteinColor)
            macroRow(.carbs, grams: carbsG, dv: RecipeNutrition.dailyValuePercent(grams: carbsG, reference: RecipeNutrition.carbsDailyG), color: carbsColor)
            macroRow(.fat, grams: fatG, dv: RecipeNutrition.dailyValuePercent(grams: fatG, reference: RecipeNutrition.fatDailyG), color: fatColor)
        }
        .padding(AppSpacing.md)
        .modifier(NutritionPanel())
    }

    private func macroRow(_ kind: MacroKind, grams: Double, dv: Int, color: Color) -> some View {
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
                    dvBar(percent: dv, color: color)
                    Text("\(Int(grams.rounded())) g")
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                    Text("\(dv)%")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
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
    }

    @ViewBuilder private func contributionList(_ kind: MacroKind) -> some View {
        let rows = nutrition.contributions(for: kind)
        if rows.isEmpty {
            Text("No ingredient breakdown for this recipe.")
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
                    Text("\(formatted(row.item.value(for: kind) * scale, kind: kind)) · \(row.percent)%")
                        .font(AppFont.body(12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Breakdown")
                    .font(AppFont.body(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(isWhole ? "Whole recipe" : "Per serving")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            // Saturated fat, sugar, and fiber are not on the recipe yet. Show the rows, not a guess.
            breakdownRow("Saturated fat", grams: nil, percent: nil)
            breakdownRow("Sugar", grams: nil, percent: nil)
            breakdownRow("Fiber", grams: nil, percent: nil)
        }
        .padding(AppSpacing.md)
        .modifier(NutritionPanel())
    }

    private func breakdownRow(_ name: String, grams: Double?, percent: Int?) -> some View {
        HStack {
            Text(name)
                .font(AppFont.body(15))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(grams.map { "\(Int(($0 * scale).rounded())) g" } ?? "—")
                .font(AppFont.body(15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
            Text(percent.map { "\($0)%" } ?? "—")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func formatted(_ value: Double, kind: MacroKind) -> String {
        if kind == .calories { return "\(Int(value.rounded())) kcal" }
        let rounded = (value * 10).rounded() / 10
        let text = rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
        return text + " g"
    }
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
