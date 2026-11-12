import Foundation
import PetaCore
import SwiftData
import UserNotifications

/// 推し活・趣味の予算のお知らせ. A notice goes out once at 8割 and once over the budget, each month.
/// The text has no amounts in it, so a locked phone shows nothing private.
enum BudgetNotifier {
    static let enabledKey = "budget.notify"
    static let budgetKey = "budget.oshi"
    private static func sentKey(_ month: String) -> String { "budget.notified.\(month)" }

    /// Asked when the person turns the notice on in 設定 (not at launch).
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// After a record is saved: compares this month's spending with the budget and sends what is new.
    static func check(context: ModelContext, now: Date = Date(), calendar: Calendar = .current,
                      defaults: UserDefaults = .standard) {
        let budget = defaults.integer(forKey: budgetKey)
        guard defaults.bool(forKey: enabledKey), budget > 0 else { return }
        let today = DayKey(date: now, calendar: calendar)
        let records = (try? context.fetch(FetchDescriptor<Record>())) ?? []
        let month = records.filter {
            let day = DayKey(date: $0.day, calendar: calendar)
            return day.year == today.year && day.month == today.month
        }
        let stats = StatsCalculator.monthStats(month.map { RecordAmount(kind: $0.kind, category: $0.category, amount: $0.amount) })
        let key = sentKey(MonthlyQuota.key(for: now, calendar: calendar))
        let sent = defaults.string(forKey: key).flatMap(BudgetUsage.Level.init(rawValue:))
        guard let level = BudgetAlert.toSend(BudgetUsage(limit: budget, spent: stats.oshiSpent), alreadySent: sent) else { return }
        defaults.set(level.rawValue, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "推し活・趣味の予算")
        content.body = level == .over
            ? String(localized: "今月の予算を超えました。集計で内訳を確かめられます。")
            : String(localized: "今月の予算の8割を使いました。")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "budget-\(level.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { @Sendable _ in }
    }
}

/// Shows the notice as a banner even while the app is open (it is usually sent right after saving).
nonisolated final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
