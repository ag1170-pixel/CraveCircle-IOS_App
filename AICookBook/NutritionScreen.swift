//
//  NutritionScreen.swift
//  CraveCircle (AICookBook)
//
//  One ring split by this meal (protein, carbs, fat), calories in the middle, daily value
//  underneath. Whole recipe multiplies the stored per-serving numbers by the batch.
//

import SwiftUI

struct NutritionScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @State private var whole = false
    @State private var openMacro: MacroKind?

    private var nutrition: RecipeNutrition { recipe.nutritionOrEstimate }
    private var servings: Int { max(recipe.servings ?? 1, 1) }
    private var shown: (kcal: Int, proteinG: Int, carbsG: Int, fatG: Int) {
        nutrition.shown(servings: servings, whole: whole)
    }
    private var scale: Double { RecipeNutrition.portionMultiplier(servings: servings, whole: whole) }

    private let proteinColor = Color(hex: "E0A02E")
    private let carbsColor = Color(hex: "E25B4C")
    private let fatColor = Color(hex: "4C8FE8")

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    portionPicker
                    ringCard
                    macros
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
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

    private var portionPicker: some View {
        HStack(spacing: 4) {
            portionChip("Per serving", on: !whole) { whole = false }
            portionChip("Whole recipe", on: whole) { whole = true }
        }
        .padding(4)
        .background(AppTheme.accentSoft, in: Capsule())
    }

    private func portionChip(_ title: String, on: Bool, tap: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            withAnimation(AppMotion.snappy) { tap() }
        } label: {
            Text(title)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(on ? AppTheme.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                mealDonut
                    .frame(width: 156, height: 156)
                VStack(alignment: .leading, spacing: 14) {
                    legend(proteinColor, "Protein", grams: shown.proteinG, share: nutrition.proteinPercent)
                    legend(carbsColor, "Carbs", grams: shown.carbsG, share: nutrition.carbsPercent)
                    legend(fatColor, "Fat", grams: shown.fatG, share: nutrition.fatPercent)
                }
                Spacer(minLength: 0)
            }
            Divider().overlay(AppTheme.separator)
            dailyGoal
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    /// One ring. Each slice is that macro's share of this meal, so the shape stays put
    /// when the portion changes. The number in the middle is the portion's calories.
    private var mealDonut: some View {
        ZStack {
            ForEach(Array(mealSlices.enumerated()), id: \.offset) { _, slice in
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(shown.kcal)")
                    .font(AppFont.display(34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("kcal")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 78)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shown.kcal) kilocalories, \(whole ? "whole recipe" : "per serving")")
    }

    private var mealSlices: [(start: Double, end: Double, color: Color)] {
        let raw = [
            (Double(nutrition.proteinPercent), proteinColor),
            (Double(nutrition.carbsPercent), carbsColor),
            (Double(nutrition.fatPercent), fatColor)
        ].filter { $0.0 > 0 }
        let sum = raw.map(\.0).reduce(0, +)
        guard sum > 0 else { return [] }
        let gap = 0.015
        var cursor = 0.0
        return raw.map { value, color in
            let span = value / sum
            let start = cursor + gap / 2
            let end = cursor + max(span - gap / 2, gap / 2)
            cursor += span
            return (min(start, 1), min(max(end, start), 1), color)
        }
    }

    private func legend(_ color: Color, _ name: String, grams: Int, share: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(grams) g · \(share)%")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    private var dailyGoal: some View {
        let pct = Int((Double(shown.kcal) / nutrition.dailyCalories * 100).rounded())
        let budget = Int(nutrition.dailyCalories.rounded())
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily goal")
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(pct)% of \(budget.formatted()) kcal")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            shareBar(percent: pct, color: AppTheme.accentInk)
            if nutrition.estimated {
                Text(whole ? "Estimated · \(servings) servings" : "Estimated · per serving")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Macronutrients")
                    .font(AppFont.body(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("% Daily Value")
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            macroRow(.protein, grams: shown.proteinG, reference: RecipeNutrition.proteinDailyG, color: proteinColor)
            macroRow(.carbs, grams: shown.carbsG, reference: RecipeNutrition.carbsDailyG, color: carbsColor)
            macroRow(.fat, grams: shown.fatG, reference: RecipeNutrition.fatDailyG, color: fatColor)
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func macroRow(_ kind: MacroKind, grams: Int, reference: Double, color: Color) -> some View {
        let daily = daily(grams, reference)
        let sources = nutrition.contributions(for: kind)
        let visible = sources.filter { $0.percent >= 15 }
        let rows = visible.isEmpty ? sources : visible
        let hidSmall = !visible.isEmpty && visible.count < sources.count
        let open = openMacro == kind
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                guard !sources.isEmpty else { return }
                Haptics.tap()
                withAnimation(AppMotion.snappy) { openMacro = open ? nil : kind }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(kind.title)
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer(minLength: 8)
                        Text("\(grams) g")
                            .font(AppFont.body(17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .monospacedDigit()
                        Text("\(daily)%")
                            .font(AppFont.body(15, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        if !sources.isEmpty {
                            Image(systemName: open ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    shareBar(percent: daily, color: color)
                }
            }
            .buttonStyle(.plain)
            .disabled(sources.isEmpty)
            .accessibilityLabel("\(kind.title), \(grams) grams, \(daily) percent of the daily value")
            if open {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Top sources")
                            .font(AppFont.label(11, weight: .bold)).tracking(0.6)
                            .foregroundStyle(AppTheme.textTertiary)
                        Spacer()
                        Text("% of your \(kind.title.lowercased())")
                            .font(AppFont.body(11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    ForEach(rows, id: \.item.name) { row in
                        let gramsShown = Int((row.item.value(for: kind) * scale).rounded())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.item.name)
                                    .font(AppFont.body(14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(gramsShown) g")
                                    .font(AppFont.body(14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .monospacedDigit()
                                Text("\(row.percent)%")
                                    .font(AppFont.body(13))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                            }
                            shareBar(percent: row.percent, color: color)
                        }
                    }
                    if hidSmall {
                        Text("Ingredients under 15% aren't shown.")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(12)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.vertical, 8)
    }

    private func shareBar(percent: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(Double(max(percent, 0)) / 100, 1))
            }
        }
        .frame(height: 6)
        .animation(AppMotion.snappy, value: whole)
    }

    private func daily(_ grams: Int, _ reference: Double) -> Int {
        RecipeNutrition.dailyValuePercent(grams: Double(grams), reference: reference)
    }

}
