//
//  MealPlanScreen.swift
//  CraveCircle (AICookBook)
//
//  Month view of the meal plan. Each day shows one colored bar per planned meal (breakfast
//  yellow, lunch blue, dinner coral, snack green) with the recipe name when it fits. Tapping a
//  day opens that day's meals. "Grocery list" jumps to the Grocery tab.
//

import SwiftUI

struct MealPlanScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var month: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var openDay: PlanDay?

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            topBar
            monthTitle
            weekdayHeader
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        weekRow(week)
                    }
                }
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { v in
                    guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                    shiftMonth(v.translation.width < 0 ? 1 : -1)
                }
            )
        }
        .overlay(alignment: .bottom) { bottomBar }
        .background(AppScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await environment.hydrateMealPlanFromServer() }
        .sheet(item: $openDay) { d in
            PlanDaySheet(day: d.date)
                .environment(environment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground { AppScreenBackground() }
        }
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.6), lineWidth: 1.2))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Back")
            Spacer()
            Button {
                Haptics.tap()
                openDay = PlanDay(date: cal.startOfDay(for: Date()))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.6), lineWidth: 1.2))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Plan a meal today")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    private var monthTitle: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(AppFont.display(34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(month.formatted(.dateTime.year()))
                .font(AppFont.body(20))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            HStack(spacing: 0) {
                arrow("chevron.left", -1, "Previous month")
                arrow("chevron.right", 1, "Next month")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    private func arrow(_ icon: String, _ delta: Int, _ label: String) -> some View {
        Button { shiftMonth(delta) } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s)
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.separator).frame(height: 1) }
    }

    // MARK: Grid

    private func weekRow(_ week: [Date]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(week, id: \.self) { dayCell($0) }
        }
        .frame(minHeight: 112, alignment: .top)
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.separator).frame(height: 1) }
    }

    private func dayCell(_ date: Date) -> some View {
        let inMonth = cal.isDate(date, equalTo: month, toGranularity: .month)
        let isToday = cal.isDateInToday(date)
        let meals = meals(on: date)
        return Button {
            Haptics.tap()
            openDay = PlanDay(date: date)
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(AppFont.body(16, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : (inMonth ? AppTheme.textPrimary : AppTheme.textTertiary))
                    .frame(width: 30, height: 30)
                    .background(isToday ? AppTheme.brand : .clear, in: Circle())
                ForEach(meals.prefix(3)) { meal in
                    Text(title(for: meal))
                        .font(AppFont.body(10, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 18)
                        .background(meal.slot.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                if meals.count > 3 {
                    Text("+\(meals.count - 3)")
                        .font(AppFont.body(10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
            .opacity(inMonth ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(date, meals))
    }

    // MARK: Bottom

    private var bottomBar: some View {
        HStack {
            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) {
                    month = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? month
                }
            } label: {
                Text("Today")
                    .font(AppFont.body(17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 22)
                    .frame(height: 50)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.textSecondary.opacity(0.5), lineWidth: 1.2))
            }
            .buttonStyle(PressableStyle())
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
                environment.requestTabSwitch(.groceries)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "basket.fill")
                    Text("Grocery list")
                }
                .font(AppFont.body(17, weight: .semibold))
                .foregroundStyle(AppTheme.onAccent)
                .padding(.horizontal, 22)
                .frame(height: 50)
                .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: Derivations

    private func shiftMonth(_ delta: Int) {
        Haptics.tap()
        withAnimation(AppMotion.snappy) {
            month = cal.date(byAdding: .month, value: delta, to: month) ?? month
        }
    }

    private var weekdaySymbols: [String] {
        let s = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    /// Whole weeks covering `month`, including the trailing/leading days of neighbouring months.
    private var weeks: [[Date]] {
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -lead, to: month),
              let days = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let count = Int((Double(lead + days) / 7).rounded(.up)) * 7
        let all = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return stride(from: 0, to: all.count, by: 7).map { Array(all[$0..<min($0 + 7, all.count)]) }
    }

    private func meals(on date: Date) -> [PlannedMeal] {
        environment.plannedMeals
            .filter { cal.isDate($0.when, inSameDayAs: date) }
            .sorted { $0.when < $1.when }
    }

    private func title(for meal: PlannedMeal) -> String {
        guard let t = environment.recipes.first(where: { $0.id == meal.recipeId })?.title else { return "" }
        return t.split(separator: " ").first(where: { $0.count > 3 }).map(String.init) ?? t
    }

    private func accessibilityText(_ date: Date, _ meals: [PlannedMeal]) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        guard !meals.isEmpty else { return "\(day), nothing planned" }
        let list = meals.map { meal in
            "\(meal.slot.displayName): \(environment.recipes.first { $0.id == meal.recipeId }?.title ?? "recipe")"
        }
        return "\(day), " + list.joined(separator: ", ")
    }
}

private struct PlanDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// One day's meals, with an "add" row per meal slot.
private struct PlanDaySheet: View {
    let day: Date
    @Environment(AppEnvironment.self) private var environment
    @State private var pickerSlot: MealSlot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(MealSlot.allCases) { slot in
                    slotSection(slot)
                }
            }
            .padding(AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
        .sheet(item: $pickerSlot) { slot in
            MealSlotRecipePickerSheet(slot: slot, day: day)
                .environment(environment)
        }
    }

    private func slotSection(_ slot: MealSlot) -> some View {
        let plans = environment.plannedMeals
            .filter { Calendar.current.isDate($0.when, inSameDayAs: day) && $0.slot == slot }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(slot.color).frame(width: 8, height: 8)
                Text(slot.displayName.uppercased())
                    .font(AppFont.body(11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(plans) { planRow($0) }
            Button {
                Haptics.tap()
                pickerSlot = slot
            } label: {
                Label("Plan \(slot.displayName.lowercased())", systemImage: "plus.circle")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func planRow(_ meal: PlannedMeal) -> some View {
        let recipe = environment.recipes.first(where: { $0.id == meal.recipeId })
        return HStack(spacing: 12) {
            if let recipe {
                RecipeCoverImage(recipe: recipe)
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe?.title ?? "Recipe not available")
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(meal.when.formatted(date: .omitted, time: .shortened)
                     + (meal.servings.map { " · \($0) servings" } ?? ""))
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 4)
            Menu {
                if let recipe {
                    Button { environment.selectRecipe(recipe) } label: {
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
                    .frame(width: 44, height: 44)
            }
        }
        .padding(10)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}
