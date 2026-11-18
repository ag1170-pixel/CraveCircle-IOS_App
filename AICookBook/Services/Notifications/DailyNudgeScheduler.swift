//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: DailyNudgeScheduler.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Local notification scheduler encouraging daily cooking habits.
//
// 2. ARCHITECTURAL ROLE:
//    Schedules personalized evening cooking reminders via UNUserNotificationCenter based on saved meal plans.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "DailyNudgeScheduler schedules intelligent local notifications to remind cooks to start dinner prep, respecting user quiet hours."
//
// ==============================================================================
//

import Foundation
import UserNotifications

enum DailyNudgeScheduler {
    typealias PlannedRecipe = (date: Date, slot: String, title: String, id: String)

    struct NudgeContext {
        let now: Date
        let lastAppActiveAt: Date?
        let plansToday: [PlannedRecipe]
        let plansTomorrow: [PlannedRecipe]
        let savedCount: Int
        let unCookedImports: Int
        let suggestedTitle: String?
    }

    private static let identifier = "daily_recipe_nudge"

    static func rescheduleDailyNudges(context: NudgeContext) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Something good to cook tomorrow?"
        if let plan = context.plansTomorrow.first {
            content.body = "Your \(plan.slot.lowercased()) plan is \(plan.title). Open CraveCircle to get ready."
            content.userInfo = ["recipe_id": plan.id]
        } else if let suggestedTitle = context.suggestedTitle {
            content.body = "Try \(suggestedTitle) from your feed tomorrow."
        } else if context.unCookedImports > 0 {
            content.body = "You have \(context.unCookedImports) imported recipe\(context.unCookedImports == 1 ? "" : "s") waiting to be cooked."
        } else if context.savedCount > 0 {
            content.body = "Pick a recipe from your \(context.savedCount) saved recipes tomorrow."
        } else {
            return
        }
        content.sound = .default

        // Schedule at a predictable local time after the user's current session; re-entering the
        // app replaces this request, so engaged users don't keep receiving stale nudges.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: context.now) ?? context.now.addingTimeInterval(24 * 60 * 60)
        let fireDate = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

/// Daily target reminder: one notification a day at 5:30 pm for the next week, each with the
/// user's own targets and a different cooking tip. Re-planned on every app open and whenever the
/// targets or the switch change, so the week keeps rolling forward.
enum TargetReminderScheduler {
    private static let prefix = "daily_target_tip_"
    private static let days = 7

    static func reschedule(targets: NutritionTargets, enabled: Bool, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<days).map { prefix + String($0) })
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let tips = tips(for: targets)
        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: now),
                  let fire = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: date),
                  fire > now else { continue }
            let tip = tips[(calendar.ordinality(of: .day, in: .era, for: fire) ?? day) % tips.count]
            let content = UNMutableNotificationContent()
            content.title = tip.title
            content.body = tip.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + String(day), content: content, trigger: trigger))
        }
    }

    /// Short, cooking-first messages built from the user's own numbers. No medical claims.
    static func tips(for t: NutritionTargets) -> [(title: String, body: String)] {
        let kcal = t.calories.formatted()
        let dinner = (t.calories * 35 / 100).formatted()
        return [
            ("Today's goal: \(kcal) kcal", "Round off the day with a home-cooked dinner. Open CraveCircle for ideas that fit."),
            ("\(t.proteinGrams) g protein today", "Eggs, paneer, chicken, lentils and fish all help. Find a high-protein recipe in CraveCircle."),
            ("Dinner around \(dinner) kcal", "That keeps you close to your \(kcal) kcal day. Each recipe's Nutrition card shows how it fits."),
            ("Cook it, track it", "Cooking at home makes your \(t.carbsGrams) g carbs and \(t.fatGrams) g fat targets easy to see on every recipe."),
            ("Plan tomorrow tonight", "Add a recipe to your Meal Plan now and tomorrow's targets take care of themselves."),
            ("Balance the plate", "Your split is \(t.carbsPercent)% carbs, \(t.fatPercent)% fat, \(t.proteinPercent)% protein. A colourful plate gets you most of the way."),
            ("Still room for a good meal", "Check a recipe's Nutrition card in CraveCircle to see what % of your day it uses.")
        ]
    }
}
