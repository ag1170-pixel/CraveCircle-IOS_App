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
    var servings: Int = 1
    @State private var showTotal = false

    // Macro data colors (distinct from the single coral accent — legitimate for data).
    private let carbsColor = AppTheme.accent
    private let proteinColor = Color(hex: "E0A02E")
    private let fatColor = Color(hex: "6E93A6")

    private var activeMultiplier: Double {
        showTotal ? Double(max(servings, 1)) : 1.0
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
                if servings > 1 {
                    Button {
                        Haptics.tap()
                        withAnimation(AppMotion.snappy) {
                            showTotal.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showTotal ? "Total (\(servings) servings)" : "Per serving")
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
                    Text(showTotal ? "Total Calories" : "Calories")
                        .font(AppFont.body(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    dvBar
                        .padding(.top, 4)
                    Text("\(activeDVPercent)% of a \(Int(nutrition.dailyCalories)) cal day")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                MacroRing(percent: activeDVPercent, color: AppTheme.accent, size: 76, lineWidth: 8,
                          label: "of daily", showPercentSuffix: true)
            }

            Rectangle().fill(AppTheme.separator).frame(height: 1)

            // Macro breakdown
            HStack(spacing: AppSpacing.sm) {
                macro("Carbs", grams: activeCarbsG, percent: nutrition.carbsPercent, color: carbsColor)
                macro("Protein", grams: activeProteinG, percent: nutrition.proteinPercent, color: proteinColor)
                macro("Fat", grams: activeFatG, percent: nutrition.fatPercent, color: fatColor)
            }

            Rectangle().fill(AppTheme.separator).frame(height: 1)

            // Kcal Burn Equivalents
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                    Text("Kcal Burn Equivalents")
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("70kg adult")
                        .font(AppFont.body(11))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                HStack(spacing: 8) {
                    burnItem(icon: "figure.run", label: "Running", minutes: Int((activeCalories / 12.0).rounded()))
                    burnItem(icon: "figure.outdoor.cycle", label: "Cycling", minutes: Int((activeCalories / 9.8).rounded()))
                    burnItem(icon: "figure.walk", label: "Walking", minutes: Int((activeCalories / 5.3).rounded()))
                }
            }
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
                    .frame(width: geo.size.width * min(Double(nutrition.caloriesDVPercent) / 100, 1))
            }
        }
        .frame(width: 150, height: 6)
    }

    private func macro(_ label: String, grams: Double, percent: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            MacroRing(percent: percent, color: color, size: 60, lineWidth: 6, label: nil, showPercentSuffix: true)
            Text("\(Int(grams))g")
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(AppFont.body(12, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func burnItem(icon: String, label: String, minutes: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accentInk)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(minutes) min")
                    .font(AppFont.body(13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(AppFont.body(10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
