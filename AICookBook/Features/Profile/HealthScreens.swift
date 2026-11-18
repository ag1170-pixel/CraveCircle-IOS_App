//
//  HealthScreens.swift
//  CraveCircle (AICookBook)
//
//  Profile → Health & diet: Diet & allergies, Health conditions, Daily targets.
//  Everything here edits `AppEnvironment.healthProfile`, which stays on this phone.
//

import SwiftUI
import UserNotifications

// MARK: - Profile section

struct HealthProfileSection: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showDiet = false
    @State private var showConditions = false
    @State private var showTargets = false

    var body: some View {
        let profile = environment.healthProfile
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Health & diet").sectionLabelStyle()
            VStack(spacing: 0) {
                SettingRow(icon: "leaf.fill", title: "Diet & allergies",
                           detail: profile.dietCount == 0 ? "None" : "\(profile.dietCount) on",
                           tint: Color(hex: "3A9D5D")) { showDiet = true }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(icon: "heart.text.square.fill", title: "Health conditions",
                           detail: profile.conditions.isEmpty ? "None" : "\(profile.conditions.count) on",
                           tint: Color(hex: "D9485F")) { showConditions = true }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(icon: "target", title: "Daily targets",
                           detail: "\(profile.targets.calories.formatted()) kcal",
                           tint: Color(hex: "E0A02E")) { showTargets = true }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            Text("Kept on this iPhone only. Used to flag recipes and tailor your suggestions. Not medical advice.")
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 4)
        }
        .navigationDestination(isPresented: $showDiet) { DietAllergiesScreen() }
        .navigationDestination(isPresented: $showConditions) { HealthConditionsScreen() }
        .navigationDestination(isPresented: $showTargets) { NutritionTargetsScreen() }
    }
}

// MARK: - Diet & allergies

struct DietAllergiesScreen: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var env = environment
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Allergens first: the choice with the highest cost if missed.
                ChoiceCard(title: "Allergens",
                           note: "Recipes that contain these are flagged and left out of Suggested for You.",
                           options: Allergen.allCases, selection: $env.healthProfile.allergens,
                           label: \.title, symbol: \.symbol)
                ChoiceCard(title: "Intolerances", note: nil,
                           options: Intolerance.allCases, selection: $env.healthProfile.intolerances,
                           label: \.title, symbol: \.symbol)
                ChoiceCard(title: "How you eat", note: nil,
                           options: DietStyle.allCases, selection: $env.healthProfile.diets,
                           label: \.title, symbol: \.symbol)
                ChoiceCard(title: "Faith & culture", note: nil,
                           options: FaithRule.allCases, selection: $env.healthProfile.faith,
                           label: \.title, symbol: \.symbol)
                Text("We match ingredient names, so always check packaged sauces and stocks yourself.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppScreenBackground())
        .navigationTitle("Diet & allergies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A titled card of toggle chips over a set.
private struct ChoiceCard<Option: Hashable & Identifiable>: View {
    let title: String
    let note: String?
    let options: [Option]
    @Binding var selection: Set<Option>
    let label: KeyPath<Option, String>
    let symbol: KeyPath<Option, String>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppFont.body(17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(selection.isEmpty ? "None" : "\(selection.count) selected")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let note {
                Text(note)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ChipFlow(spacing: 8) {
                ForEach(options) { option in
                    let on = selection.contains(option)
                    Button {
                        Haptics.toggle(!on)
                        if on { selection.remove(option) } else { selection.insert(option) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option[keyPath: symbol])
                                .font(.system(size: 12, weight: .bold))
                            Text(option[keyPath: label])
                                .font(AppFont.body(14, weight: .semibold))
                        }
                        .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(on ? AppTheme.accent : AppTheme.background, in: Capsule())
                        .overlay(Capsule().stroke(on ? .clear : AppTheme.hairline, lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}

/// Lays chips left to right, wrapping to a new line when a row is full.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], needed, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Health conditions

struct HealthConditionsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var pending: HealthCondition?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Turn on what applies to you. We'll show what it changes before it takes effect.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(HealthCondition.allCases.enumerated()), id: \.element) { index, condition in
                        if index > 0 { Divider().overlay(AppTheme.separator).padding(.leading, 56) }
                        row(condition)
                    }
                }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

                Text("CraveCircle gives cooking guidance, not medical advice. Follow your doctor's or dietitian's plan.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppScreenBackground())
        .navigationTitle("Health conditions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pending) { condition in
            ConditionConfirmSheet(condition: condition) {
                environment.healthProfile.conditions.insert(condition)
                pending = nil
            } onCancel: {
                pending = nil
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
    }

    private func row(_ condition: HealthCondition) -> some View {
        let on = environment.healthProfile.conditions.contains(condition)
        return Button {
            if on {
                Haptics.toggle(false)
                environment.healthProfile.conditions.remove(condition)
            } else {
                Haptics.tap()
                pending = condition
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: condition.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(on ? AppTheme.accent : AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(condition.title)
                    .font(AppFont.body(16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if on {
                    Text("On")
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityHint(on ? "Turns it off" : "Shows what it changes")
    }
}

private struct ConditionConfirmSheet: View {
    let condition: HealthCondition
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: condition.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(condition.title)
                    .font(AppFont.display(22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("What changes").sectionLabelStyle()
                Text(condition.whatChanges)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            PillButton(title: "Turn on", kind: .filled, fullWidth: true, action: onConfirm)
            Button("Not now", action: onCancel)
                .font(AppFont.body(15, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(AppSpacing.lg)
        .background(AppScreenBackground())
    }
}

// MARK: - Daily targets

struct NutritionTargetsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NutritionTargets()
    @State private var loaded = false

    private let carbsColor = Color(hex: "E25B4C")
    private let fatColor = Color(hex: "4C8FE8")
    private let proteinColor = Color(hex: "E0A02E")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Calories").sectionLabelStyle()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.calories.formatted())
                                .font(AppFont.display(32, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("kcal a day")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        StepButtons(label: "calories",
                                    canDown: draft.calories > NutritionTargets.calorieRange.lowerBound,
                                    canUp: draft.calories < NutritionTargets.calorieRange.upperBound) { step in
                            draft.calories = min(max(draft.calories + step * 50, NutritionTargets.calorieRange.lowerBound),
                                                 NutritionTargets.calorieRange.upperBound)
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Macro split").sectionLabelStyle()
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        splitBar
                        macroRow("Carbs", grams: draft.carbsGrams, percent: $draft.carbsPercent, color: carbsColor)
                        macroRow("Fat", grams: draft.fatGrams, percent: $draft.fatPercent, color: fatColor)
                        macroRow("Protein", grams: draft.proteinGrams, percent: $draft.proteinPercent, color: proteinColor)
                        Divider().overlay(AppTheme.separator)
                        HStack {
                            Text("Total")
                                .font(AppFont.body(15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(draft.totalPercent == 100 ? "100%" : "\(draft.totalPercent)% · needs 100%")
                                .font(AppFont.body(15, weight: .bold))
                                .foregroundStyle(draft.totalPercent == 100 ? Color(hex: "3A9D5D") : AppTheme.destructive)
                                .monospacedDigit()
                        }
                    }
                    .card()
                }

                reminderCard

                Text("These set the \"% of your day\" on every recipe's nutrition card.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 4)

                PillButton(title: "Save targets", kind: .filled, fullWidth: true) {
                    environment.healthProfile.targets = draft
                    Haptics.success()
                    dismiss()
                }
                .disabled(draft.totalPercent != 100 || draft == environment.healthProfile.targets)
                .opacity(draft.totalPercent != 100 || draft == environment.healthProfile.targets ? 0.5 : 1)

                if draft != NutritionTargets() {
                    Button("Reset to 2,000 kcal · 50 / 30 / 20") {
                        Haptics.tap()
                        withAnimation(.snappy) { draft = NutritionTargets() }
                    }
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppScreenBackground())
        .navigationTitle("Daily targets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            draft = environment.healthProfile.targets
            loaded = true
        }
        .animation(.snappy, value: draft)
    }

    /// Daily reminder switch. Applies at once (not part of the Save draft) and asks for
    /// notification permission the first time it's turned on.
    private var reminderCard: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily reminder")
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("5:30 pm · your targets and a cooking tip")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { environment.healthProfile.targetReminder },
                set: { on in
                    if on {
                        Task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            environment.healthProfile.targetReminder = true
                        }
                    } else {
                        environment.healthProfile.targetReminder = false
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(GlassToggleStyle())
            .accessibilityLabel("Daily reminder")
        }
        .card()
    }

    private var splitBar: some View {
        GeometryReader { geo in
            let total = max(CGFloat(draft.totalPercent), 1)
            HStack(spacing: 3) {
                Capsule().fill(carbsColor).frame(width: geo.size.width * CGFloat(draft.carbsPercent) / max(total, 100))
                Capsule().fill(fatColor).frame(width: geo.size.width * CGFloat(draft.fatPercent) / max(total, 100))
                Capsule().fill(proteinColor).frame(width: geo.size.width * CGFloat(draft.proteinPercent) / max(total, 100))
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private func macroRow(_ name: String, grams: Int, percent: Binding<Int>, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(grams) g")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            Text("\(percent.wrappedValue)%")
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
            StepButtons(label: name.lowercased(), canDown: percent.wrappedValue > 5, canUp: percent.wrappedValue < 80) { step in
                percent.wrappedValue = min(max(percent.wrappedValue + step * 5, 5), 80)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A minus and a plus button, 44pt targets.
private struct StepButtons: View {
    let label: String
    let canDown: Bool
    let canUp: Bool
    let change: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            button("minus", step: -1, enabled: canDown, name: "Less \(label)")
            button("plus", step: 1, enabled: canUp, name: "More \(label)")
        }
    }

    private func button(_ symbol: String, step: Int, enabled: Bool, name: String) -> some View {
        Button {
            Haptics.select()
            change(step)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.background, in: Circle())
                .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(name)
    }
}

private extension View {
    func card() -> some View {
        padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }
}

// MARK: - Recipe page alert

/// A small capsule beside the cook time when a recipe clashes with the user's health & diet
/// settings: red for hard clashes (allergy, diet, faith, intolerance), amber for heads-ups.
/// Tapping it shows the reasons in a popover, so the page itself stays uncluttered.
struct HealthAlertPill: View {
    let flags: [HealthFlag]
    @State private var showing = false

    var body: some View {
        let hard = flags.contains(where: \.hard)
        let tint = hard ? Color(hex: "E5484D") : Color(hex: "D9961A")
        Button {
            Haptics.tap()
            showing = true
        } label: {
            Image(systemName: "flag.fill")
                .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: 28)
            .background(tint, in: Capsule())
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(hard ? "Health alert" : "Health heads-up")
        .accessibilityValue(flags.map(\.text).joined(separator: ", "))
        .popover(isPresented: $showing, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(hard ? "Check before cooking" : "Heads-up for you")
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(flags, id: \.self) { flag in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(flag.hard ? Color(hex: "E5484D") : Color(hex: "D9961A"))
                            .frame(width: 7, height: 7)
                        Text(flag.text)
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                Text("Based on your Health & diet settings.")
                    .font(AppFont.body(12))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(AppSpacing.md)
            .frame(minWidth: 220, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}

#if DEBUG
#Preview("Health checks") {
    HealthCheck.selfCheck()
    return HealthAlertPill(flags: [HealthFlag(text: "Contains peanuts", hard: true), HealthFlag(text: "Added sugar", hard: false)])
        .padding()
}
#endif
