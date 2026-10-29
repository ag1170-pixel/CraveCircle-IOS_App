//
//  MealSlotRecipePickerSheet.swift
//  CraveCircle (AICookBook)
//
//  Opens from MealPlanScreen when the user taps an empty breakfast/lunch/dinner/snack tile.
//  Shows a 2-col grid of recipes that fit the picked slot (via Recipe.mealSlots) so the user
//  can tap one and have it planned for the focused day + slot in a single interaction.
//

import SwiftUI

struct MealSlotRecipePickerSheet: View {
    let slot: MealSlot
    let day: Date
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    private var matches: [Recipe] {
        environment.recipes.filter { $0.mealSlots.contains(slot) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No \(slot.displayName.lowercased()) recipes yet",
                        systemImage: slot.systemImage,
                        description: Text("Import or publish a recipe tagged for \(slot.displayName.lowercased()) and it'll show up here.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                            ForEach(matches) { recipe in
                                tile(for: recipe)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Plan \(slot.displayName.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func tile(for recipe: Recipe) -> some View {
        Button {
            Haptics.success()
            Task {
                // The planned time is the slot's typical hour on the focused day. User can
                // adjust the exact time later from the plan card's menu.
                let when = Self.defaultTime(for: slot, on: day)
                _ = await environment.planMeal(recipeId: recipe.id, when: when, slot: slot)
                await MainActor.run { dismiss() }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
                Text(recipe.title)
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }

    /// Default clock-time per slot. 8am breakfast / 1pm lunch / 7pm dinner / 4pm snack.
    static func defaultTime(for slot: MealSlot, on day: Date, in cal: Calendar = .current) -> Date {
        let hour: Int = {
            switch slot {
            case .breakfast: return 8
            case .lunch:     return 13
            case .dinner:    return 19
            case .snack:     return 16
            }
        }()
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
