import Foundation
import UserNotifications
import FYLCore

/// iOS bildirim merkezi ile FYLCore arasındaki köprü. Bütün bekleyen bildirimler bu uygulamanın:
/// her kurulumda hepsi silinip yeniden kurulur (0.2.0'dan kalan `plan-`/`fu-` bildirimleri de gider).
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    weak var model: AppModel?
    private let center = UNUserNotificationCenter.current()
    private let idFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMddHHmm"; return f
    }()

    func apply(reminders: [Reminder], noon: String?, noonMinute: Int) async {
        center.removeAllPendingNotificationRequests()
        center.setNotificationCategories([])
        for r in reminders {
            let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.fireAt)
            await add("cal-\(idFormat.string(from: r.fireAt))", title: "Takvim", body: r.lines.joined(separator: "\n"),
                      tab: "calendar", UNCalendarNotificationTrigger(dateMatching: c, repeats: false))
        }
        if let noon {
            await add("wish-noon", title: "Alınacaklar", body: noon, tab: "wishes",
                      UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: noonMinute / 60, minute: noonMinute % 60), repeats: true))
        }
    }

    private func add(_ id: String, title: String, body: String, tab: String, _ trigger: UNNotificationTrigger) async {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default; c.userInfo = ["tab": tab]
        try? await center.add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }

    // async sürüm: iOS, fonksiyon dönünce tamamlandı sayar.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let tab = response.notification.request.content.userInfo["tab"] as? String
        await model?.open(tab)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
