import Foundation
import UserNotifications
import FYLCore

/// iOS bildirim merkezi ile FYLCore arasındaki köprü. Aksiyon id'si "indeks:etiket" ("0:nefret"):
/// içerik güncellenip butonlar yer değiştirirse eski bildirimdeki cevap yanlış etikete yazılmaz.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    weak var model: AppModel?
    private let center = UNUserNotificationCenter.current()

    func registerCategories(_ content: Content) {
        let cats = content.nodes.map { id, node in
            UNNotificationCategory(
                identifier: id,
                actions: node.buttons.enumerated().map { i, b in
                    let opts: UNNotificationActionOptions = b.foreground == true ? [.foreground] : []
                    let aid = "\(i):\(b.tag)"
                    return b.input == true
                        ? UNTextInputNotificationAction(identifier: aid, title: b.title, options: opts,
                                                        textInputButtonTitle: "Gönder", textInputPlaceholder: "")
                        : UNNotificationAction(identifier: aid, title: b.title, options: opts)
                },
                intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: content.placeholder, options: [])
        }
        center.setNotificationCategories(Set(cats))
    }

    /// Planlı bildirimlerin tamamını yenisiyle değiştirir (takip bildirimlerine dokunmaz).
    func apply(_ items: [PlannedItem]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("plan-") })
        for it in items {
            let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: it.date)
            try? await center.add(UNNotificationRequest(
                identifier: it.id,
                content: Self.body(it.text, node: it.nodeId, itemId: it.id, questIndex: it.questIndex, depth: 1),
                trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
    }

    func send(_ f: FollowUp, itemId: String, after seconds: TimeInterval = 3) async {
        try? await center.add(UNNotificationRequest(
            identifier: "fu-\(UUID().uuidString)",
            content: Self.body(f.text, node: f.nodeId, itemId: itemId, questIndex: f.questIndex, depth: f.depth),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
    }

    private static func body(_ text: String, node: String, itemId: String, questIndex: Int?, depth: Int) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.body = text; c.sound = .default; c.categoryIdentifier = node
        var info: [String: Any] = ["itemId": itemId, "nodeId": node, "depth": depth]
        if let q = questIndex { info["questIndex"] = q }
        c.userInfo = info
        return c
    }

    // async sürümler: iOS, fonksiyon dönünce (yani bildirimler kurulduktan sonra) tamamlandı sayar.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await model?.receive(response)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
