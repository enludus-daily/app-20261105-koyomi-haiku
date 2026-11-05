import Foundation
import UserNotifications

/// 朝のお知らせ：その日の候と季語を、端末の中で予約する（通信しない）。
/// 先の 14 日分を、日ごとの季語で入れておく（開くたびに入れ直す）。
enum Reminder {
    static let idPrefix = "koyomi.morning."
    static let days = 14

    /// お知らせの文（テストできるように切り出す）
    static func content(for date: Date, calendar: Calendar) -> (title: String, body: String) {
        let kou = Almanac.kou(on: date, calendar: calendar)
        let kigo = Almanac.todaysKigo(on: date, calendar: calendar)
        return ("\(kou.sekki) \(kou.phase)「\(kou.name)」", "今日の季語は「\(kigo.word)」。\(kigo.prompt)")
    }

    enum Permission { case allowed, denied, notAsked }

    static func permission() async -> Permission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        default: return .notAsked
        }
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(hour: Int, minute: Int, from now: Date = .now, calendar: Calendar = .current) async {
        await cancel()
        let center = UNUserNotificationCenter.current()
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            let text = content(for: fire, calendar: calendar)
            let c = UNMutableNotificationContent()
            c.title = text.title
            c.body = text.body
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: idPrefix + "\(offset)", content: c,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            try? await center.add(request)
        }
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
