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
