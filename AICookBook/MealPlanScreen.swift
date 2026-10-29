//
//  MealPlanScreen.swift
//  CraveCircle (AICookBook)
//
//  Pushed from Profile → "Meal Plan". Minimal, iOS-native: a horizontal week strip at the top,
//  then four slot rows for the focused day (Breakfast / Lunch / Dinner / Snack). Each slot is
//  either a recipe card or an empty "Add" tile that opens the Discover reel so the user can
//  pick something to plan.
//

import SwiftUI

struct MealPlanScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var focused: Date = Calendar.current.startOfDay(for: Date())
    @State private var weekAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var pickerSlot: MealSlot?    // non-nil → show the slot-filtered recipe picker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                weekStrip
                dayHeader
                slotsList
                if !upcomingBeyondFocused.isEmpty {
                    upcomingSection
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Meal Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .task { await environment.hydrateMealPlanFromServer() }
        .sheet(item: $pickerSlot) { slot in
            MealSlotRecipePickerSheet(slot: slot, day: focused)
                .environmentObject(environment)
        }
    }

    // MARK: Week strip

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { day in
                dayPill(for: day)
            }
        }
    }

    private func dayPill(for day: Date) -> some View {
        let cal = Calendar.current
        let isFocused = cal.isDate(day, inSameDayAs: focused)
        let isToday = cal.isDateInToday(day)
        return Button {
            Haptics.tap()
            withAnimation(AppMotion.snappy) { focused = day }
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppFont.body(11, weight: .semibold))
                    .foregroundStyle(isFocused ? AppTheme.onAccent : AppTheme.textSecondary)
                Text(day.formatted(.dateTime.day()))
                    .font(AppFont.serif(16, weight: .bold))
                    .foregroundStyle(isFocused ? AppTheme.onAccent : AppTheme.textPrimary)
                Circle()
                    .fill(hasPlans(on: day) ? (isFocused ? AppTheme.onAccent : AppTheme.brand) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isFocused ? AppTheme.accent : (isToday ? AppTheme.accentSoft : AppTheme.surface),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? Color.clear : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Day header

    private var dayHeader: some View {
        HStack {
            Text(focused.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(AppFont.body(18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if !plansForFocused.isEmpty, let roll = macroRollup {
                Text("~\(Int(roll.calories)) kcal · \(Int(roll.protein))g P")
                    .font(AppFont.body(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: Slots

    private var slotsList: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(MealSlot.allCases) { slot in
                slotRow(for: slot)
            }
        }
    }

    private func slotRow(for slot: MealSlot) -> some View {
        let plans = plansForFocused.filter { $0.slot == slot }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: slot.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(slot.displayName.uppercased())
                    .font(AppFont.body(11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(0.8)
                Spacer()
            }
            if plans.isEmpty {
                emptyTile(slot: slot)
            } else {
                ForEach(plans) { planCard(for: $0) }
            }
        }
    }

    private func emptyTile(slot: MealSlot) -> some View {
        // Tap → open the slot-filtered recipe grid so the user picks something to plan without
        // leaving the Meal Plan screen. The picker only shows recipes classified for this slot.
        Button {
            Haptics.tap()
            pickerSlot = slot
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Plan \(slot.displayName.lowercased())")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func planCard(for meal: PlannedMeal) -> some View {
        let recipe = environment.recipes.first(where: { $0.id == meal.recipeId })
        return HStack(spacing: 12) {
            if let recipe {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.hairline, lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe?.title ?? "Recipe not available")
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(meal.when.formatted(date: .omitted, time: .shortened))
                    .font(AppFont.body(11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 4)
            Menu {
                if let recipe {
                    Button {
                        environment.selectRecipe(recipe)
                    } label: {
                        Label("Open recipe", systemImage: "arrow.up.right.square")
                    }
                }
                Button(role: .destructive) {
                    Task { await environment.unplanMeal(id: meal.id) }
                } label: {
                    Label("Remove plan", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(10)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upcoming").sectionLabelStyle()
            VStack(spacing: 0) {
                ForEach(upcomingBeyondFocused.prefix(6)) { meal in
                    HStack {
                        Text(meal.when.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(AppFont.body(13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(" · \(meal.slot.displayName)")
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text(environment.recipes.first(where: { $0.id == meal.recipeId })?.title ?? "")
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 10)
                    if meal.id != upcomingBeyondFocused.prefix(6).last?.id {
                        Divider().overlay(AppTheme.separator)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: Derivations

    private var weekDays: [Date] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -3, to: weekAnchor) ?? weekAnchor
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var plansForFocused: [PlannedMeal] {
        environment.plannedMeals.filter { Calendar.current.isDate($0.when, inSameDayAs: focused) }
    }

    private var upcomingBeyondFocused: [PlannedMeal] {
        environment.plannedMeals
            .filter { $0.when > focused && !Calendar.current.isDate($0.when, inSameDayAs: focused) }
            .sorted { $0.when < $1.when }
    }

    private func hasPlans(on day: Date) -> Bool {
        environment.plannedMeals.contains { Calendar.current.isDate($0.when, inSameDayAs: day) }
    }

    /// Rough per-day macro roll-up — sums per-serving nutrition over planned recipes for the
    /// focused day, for a one-line sidebar in the header. Only reads what the recipe already has.
    private var macroRollup: (calories: Double, protein: Double)? {
        var cal = 0.0, protein = 0.0
        var found = false
        for meal in plansForFocused {
            if let r = environment.recipes.first(where: { $0.id == meal.recipeId }),
               let n = r.nutrition {
                cal += n.calories
                protein += n.proteinG
                found = true
            }
        }
        return found ? (cal, protein) : nil
    }
}
