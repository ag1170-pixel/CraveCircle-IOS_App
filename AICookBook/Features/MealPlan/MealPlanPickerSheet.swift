//
//  MealPlanPickerSheet.swift
//  CraveCircle (AICookBook)
//
//  "Add to meal plan" sheet from a recipe page: month calendar (dots mark meals already
//  planned that day, one per meal slot), meal chips, time and servings, one primary button.
//

import SwiftUI

struct MealPlanPickerSheet: View {
    let recipe: Recipe
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var day: Date
    @State private var month: Date
    @State private var slot: MealSlot = .dinner
    @State private var time: Date
    @State private var servings: Int
    @State private var editingTime = false
    @State private var saving = false

    private let cal = Calendar.current

    init(recipe: Recipe) {
        self.recipe = recipe
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        _day = State(initialValue: today)
        _month = State(initialValue: cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today)
        _time = State(initialValue: cal.date(bySettingHour: 19, minute: 30, second: 0, of: today) ?? today)
        _servings = State(initialValue: recipe.servings ?? 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                recipeRow
                calendarCard
                mealChips
                detailsCard
                addButton
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .presentationBackground { AppScreenBackground() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Add to meal plan")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.6), lineWidth: 1.2))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Close")
        }
    }

    private var recipeRow: some View {
        HStack(spacing: 12) {
            RecipeCoverImage(recipe: recipe)
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(recipeMeta)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var recipeMeta: String {
        var parts: [String] = []
        if let s = recipe.servings { parts.append("\(s) servings") }
        if let t = recipe.cookTime ?? recipe.prepTime, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " · ")
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(month.formatted(.dateTime.year()))
                    .font(AppFont.display(20, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                monthButton("chevron.left", by: -1, label: "Previous month")
                monthButton("chevron.right", by: 1, label: "Next month")
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(AppFont.body(12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) } else { Color.clear.frame(height: 48) }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func monthButton(_ icon: String, by delta: Int, label: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(AppMotion.snappy) {
                month = cal.date(byAdding: .month, value: delta, to: month) ?? month
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = cal.isDate(date, inSameDayAs: day)
        let isToday = cal.isDateInToday(date)
        let past = date < cal.startOfDay(for: Date())
        let slots = plannedSlots(on: date)
        return Button {
            Haptics.select()
            withAnimation(AppMotion.snappy) { day = date }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(AppFont.body(17, weight: selected || isToday ? .bold : .regular))
                    .foregroundStyle(selected ? Color.white : (isToday ? AppTheme.brand : AppTheme.textPrimary))
                    .frame(width: 34, height: 34)
                    .background(selected ? AppTheme.brand : .clear, in: Circle())
                HStack(spacing: 3) {
                    ForEach(slots, id: \.self) { Circle().fill($0.color).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .opacity(past ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(past)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Meal

    private var mealChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEAL")
                .font(AppFont.body(12, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 6) {
                ForEach(MealSlot.allCases) { s in
                    let on = s == slot
                    Button {
                        Haptics.select()
                        withAnimation(AppMotion.snappy) {
                            slot = s
                            time = cal.date(bySettingHour: defaultHour(for: s).h, minute: defaultHour(for: s).m,
                                            second: 0, of: time) ?? time
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                            Text(s.displayName).font(AppFont.body(15, weight: .medium))
                        }
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(on ? AppTheme.accent : AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(on ? .clear : AppTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func defaultHour(for s: MealSlot) -> (h: Int, m: Int) {
        switch s {
        case .breakfast: return (8, 30)
        case .lunch:     return (13, 0)
        case .dinner:    return (19, 30)
        case .snack:     return (16, 30)
        }
    }

    // MARK: Time + servings

    private var detailsCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(AppMotion.snappy) { editingTime.toggle() }
            } label: {
                detailRow(icon: "clock", title: "Time", value: time.formatted(date: .omitted, time: .shortened),
                          chevron: editingTime ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.plain)
            if editingTime {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()
            }
            Divider().overlay(AppTheme.separator).padding(.leading, 44)
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 20)
                Text("Servings")
                    .font(AppFont.body(17))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Stepper(value: $servings, in: 1...24) {
                    Text("\(servings)")
                        .font(AppFont.body(17))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                }
                .fixedSize()
                .accessibilityLabel("Servings")
                .accessibilityValue("\(servings)")
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 56)
        }
        .background(AppTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func detailRow(icon: String, title: String, value: String, chevron: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            Text(title)
                .font(AppFont.body(17))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(AppFont.body(17))
                .foregroundStyle(AppTheme.textSecondary)
            Image(systemName: chevron)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    // MARK: Add

    private var addButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if saving {
                    ProgressView().tint(AppTheme.onAccent)
                } else {
                    Image(systemName: "calendar.badge.plus")
                    Text("Add to \(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                }
            }
            .font(AppFont.body(17, weight: .semibold))
            .foregroundStyle(AppTheme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppTheme.accent, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(saving)
        .padding(.top, AppSpacing.xs)
    }

    private func save() {
        guard !saving else { return }
        saving = true
        let parts = cal.dateComponents([.hour, .minute], from: time)
        let when = cal.date(bySettingHour: parts.hour ?? 19, minute: parts.minute ?? 0, second: 0, of: day) ?? day
        Task {
            let meal = await environment.planMeal(recipeId: recipe.id, when: when, slot: slot, servings: servings)
            saving = false
            if meal != nil {
                Haptics.success()
                dismiss()
            } else {
                Haptics.warning()
            }
        }
    }

    // MARK: Derivations

    private var weekdaySymbols: [String] {
        let s = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    /// Leading blanks, then each day of `month`.
    private var monthCells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: lead) + days
    }

    private func plannedSlots(on date: Date) -> [MealSlot] {
        let used = Set(environment.plannedMeals.filter { cal.isDate($0.when, inSameDayAs: date) }.map(\.slot))
        return MealSlot.allCases.filter(used.contains)
    }
}
