//
//  MealPlanPickerSheet.swift
//  CraveCircle (AICookBook)
//
//  One native-feel sheet to add a recipe to the meal plan. Three parts, no typing:
//    1. Quick picks row — Today / Tomorrow / This weekend. One tap and the picker's done.
//    2. Apple's `DatePicker(..., [.date, .hourAndMinute])` graphical style — spin a wheel.
//    3. Breakfast / Lunch / Dinner / Snack segmented control — defaults to the slot the
//       picked time suggests.
//    4. Save button at the bottom.
//

import SwiftUI

struct MealPlanPickerSheet: View {
    let recipe: Recipe
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var when: Date
    @State private var slot: MealSlot
    @State private var saving = false

    init(recipe: Recipe) {
        self.recipe = recipe
        // Default: tomorrow at 7 PM — covers the most common "plan tomorrow's dinner" case.
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let d = cal.date(bySettingHour: 19, minute: 0, second: 0, of: base) ?? base
        _when = State(initialValue: d)
        _slot = State(initialValue: .dinner)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        quickPick("Today",    date: today(hour: 19))
                        quickPick("Tomorrow", date: tomorrow(hour: 19))
                        quickPick("Weekend",  date: nextSaturday(hour: 19))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                Section("When") {
                    DatePicker("Date & time", selection: $when, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .onChange(of: when) { _, newValue in
                            // Auto-pick a slot that fits the picked time; user can override.
                            slot = MealSlot.suggested(for: newValue)
                        }
                }

                Section("Meal") {
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { s in
                            Label(s.displayName, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // Show existing plans for this recipe so a double-booking is obvious.
                let existing = environment.plannedMeals(for: recipe.id)
                if !existing.isEmpty {
                    Section("Already planned") {
                        ForEach(existing) { m in
                            HStack {
                                Image(systemName: m.slot.systemImage)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(formatted(m.when))
                                    .font(AppFont.body(14))
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await environment.unplanMeal(id: m.id) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(AppTheme.destructive)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Plan to cook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if saving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(saving)
                }
            }
            .tint(AppTheme.accentInk)
        }
    }

    // MARK: Quick-pick chip

    private func quickPick(_ label: String, date: Date) -> some View {
        Button {
            Haptics.tap()
            when = date
            slot = MealSlot.suggested(for: date)
        } label: {
            Text(label)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Date helpers

    private func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func tomorrow(hour: Int) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }

    private func nextSaturday(hour: Int) -> Date {
        let cal = Calendar.current
        let today = Date()
        // 7 = Saturday in Gregorian calendar
        var days = (7 - cal.component(.weekday, from: today) + 7) % 7
        if days == 0 { days = 7 }
        let base = cal.date(byAdding: .day, value: days, to: today) ?? today
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f.string(from: date)
    }

    private func save() {
        saving = true
        Task {
            let meal = await environment.planMeal(recipeId: recipe.id, when: when, slot: slot)
            await MainActor.run {
                saving = false
                if meal != nil {
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.warning()
                }
            }
        }
    }
}
