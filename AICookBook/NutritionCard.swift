//
//  NutritionCard.swift
//  CraveCircle (AICookBook)
//
//  Per-serving nutrition — calories + a carbs/protein/fat macro breakdown as rings.
//  Values come from the recipe (server-computed) or an on-device estimate.
//

import SwiftUI

struct NutritionCard: View {
    let nutrition: RecipeNutrition
    var servings: Int = 1          // how many servings the user is splitting the dish into (stepper)
    var baseServings: Int = 1      // the recipe's own serving count (what the stored per-serving used)
    @State private var showTotal = false
    @State private var selectedMacro: MacroKind? = nil

    private var hasBreakdown: Bool { (nutrition.breakdown?.isEmpty == false) }

    private func color(for kind: MacroKind) -> Color {
        switch kind {
        case .calories: return AppTheme.accent
        case .carbs:    return carbsColor
        case .protein:  return proteinColor
        case .fat:      return fatColor
        }
    }

    private func selectMacro(_ kind: MacroKind) {
        guard hasBreakdown else { return }
        Haptics.tap()
        withAnimation(AppMotion.snappy) {
            selectedMacro = (selectedMacro == kind) ? nil : kind
        }
    }

    // Macro data colors (distinct from the single coral accent — legitimate for data).
    private let carbsColor = AppTheme.accent
    private let proteinColor = Color(hex: "E0A02E")
    private let fatColor = Color(hex: "6E93A6")

    // Model A: the dish is fixed. Whole recipe = stored per-serving × baseServings (constant).
    // Per serving = whole recipe ÷ current servings → drops as you raise the servings stepper.
    private var perServingScale: Double { Double(max(baseServings, 1)) / Double(max(servings, 1)) }
    private var activeMultiplier: Double {
        showTotal ? Double(max(baseServings, 1)) : perServingScale
    }

    private var activeCalories: Double {
        nutrition.calories * activeMultiplier
    }

    private var activeCarbsG: Double {
        nutrition.carbsG * activeMultiplier
    }

    private var activeProteinG: Double {
        nutrition.proteinG * activeMultiplier
    }

    private var activeFatG: Double {
        nutrition.fatG * activeMultiplier
    }

    private var activeDVPercent: Int {
        Int(((activeCalories / nutrition.dailyCalories) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nutrition").sectionLabelStyle(AppTheme.accentInk)
                Spacer()
                if baseServings > 1 {
                    Button {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) {
                            showTotal.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showTotal ? "Whole recipe" : "Per serving")
                                .font(AppFont.body(12, weight: .semibold))
                            Image(systemName: "arrow.2.squarepath")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.accentInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(nutrition.estimated ? "Estimated · per serving" : "Per serving")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            // Calories + daily-value ring
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(activeCalories)) kcal")
                        .font(AppFont.display(28, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(AppMotion.snappy, value: activeCalories)
                    Text(showTotal ? "Whole Recipe" : "Calories")
                        .font(AppFont.body(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    dvBar
                        .padding(.top, 4)
                    Text("\(activeDVPercent)% of a \(Int(nutrition.dailyCalories)) cal day")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectMacro(.calories) }
                Spacer()
                MacroRing(percent: activeDVPercent, color: AppTheme.accent, size: 76, lineWidth: 8,
                          label: "of daily", showPercentSuffix: true)
            }

            Rectangle().fill(AppTheme.separator).frame(height: 1)

            // Macro breakdown — tap a macro to see which ingredients bring it.
            HStack(spacing: AppSpacing.sm) {
                macroButton(.carbs, grams: activeCarbsG, percent: nutrition.carbsPercent, color: carbsColor)
                macroButton(.protein, grams: activeProteinG, percent: nutrition.proteinPercent, color: proteinColor)
                macroButton(.fat, grams: activeFatG, percent: nutrition.fatPercent, color: fatColor)
            }

            if hasBreakdown && selectedMacro == nil {
                Text("Tap a macro to see what it comes from")
                    .font(AppFont.body(11))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            breakdownPanel
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var dvBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.separator)
                Capsule().fill(AppTheme.accent)
                    .frame(width: geo.size.width * min(Double(activeDVPercent) / 100, 1))
                    .animation(AppMotion.snappy, value: activeDVPercent)
            }
        }
        .frame(width: 150, height: 6)
    }

    private func macroButton(_ kind: MacroKind, grams: Double, percent: Int, color: Color) -> some View {
        let isSelected = selectedMacro == kind
        return Button {
            selectMacro(kind)
        } label: {
            VStack(spacing: 6) {
                MacroRing(percent: percent, color: color, size: 60, lineWidth: 6, label: nil, showPercentSuffix: true)
                Text("\(Int(grams))g")
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(AppMotion.snappy, value: grams)
                Text(kind.title)
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.10) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!hasBreakdown)
    }

    // MARK: Tappable breakdown

    @ViewBuilder private var breakdownPanel: some View {
        if let kind = selectedMacro {
            let rows = nutrition.contributions(for: kind)
            let tint = color(for: kind)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Where the \(kind.title.lowercased()) comes from")
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button { withAnimation(AppMotion.snappy) { selectedMacro = nil } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close breakdown")
                }
                if rows.isEmpty {
                    Text("No \(kind.title.lowercased()) sources we could identify in this recipe.")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                } else {
                    ForEach(rows, id: \.item.name) { row in
                        contributionRow(kind: kind, item: row.item, percent: row.percent, tint: tint)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func contributionRow(kind: MacroKind, item: IngredientMacro, percent: Int, tint: Color) -> some View {
        let value = item.value(for: kind) * activeMultiplier
        return VStack(spacing: 5) {
            HStack {
                Text(item.name)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(fmtValue(value, kind: kind)) · \(percent)%")
                    .font(AppFont.body(12, weight: .semibold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * min(Double(percent) / 100, 1))
                }
            }
            .frame(height: 5)
        }
    }

    private func fmtValue(_ v: Double, kind: MacroKind) -> String {
        if kind == .calories { return "\(Int(v.rounded())) kcal" }
        let r = (v * 10).rounded() / 10
        return (r == r.rounded() ? "\(Int(r))" : String(format: "%.1f", r)) + "g"
    }

}

// MARK: - Ring

struct MacroRing: View {
    let percent: Int
    let color: Color
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6
    var label: String? = nil
    var showPercentSuffix: Bool = true

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(Double(percent) / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(showPercentSuffix ? "\(percent)%" : "\(percent)")
                    .font(AppFont.body(size > 68 ? 18 : 14, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                if let label {
                    Text(label).font(AppFont.body(9, weight: .medium)).foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    NutritionCard(nutrition: RecipeNutrition(calories: 520, carbsG: 42, proteinG: 28, fatG: 26))
        .padding()
}
