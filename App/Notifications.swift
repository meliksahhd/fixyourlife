import Foundation
import UserNotifications
import FYLCore

/// iOS bildirim merkezi ile FYLCore arasındaki köprü. Aksiyon id'si "indeks:etiket" ("0:nefret"):
/// içerik güncellenip butonlar yer değiştirirse eski bildirimdeki cevap yanlış etikete yazılmaz.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    weak var model: AppModel?
    private let center = UNUserNotificationCenter.current()
    private var gists: [String: String] = [:]   // düğüm → alt satır

    func registerCategories(_ content: Content) {
        gists = content.nodes.compactMapValues(\.gist)
        let cats = content.nodes.map { id, node in
            UNNotificationCategory(
                identifier: id,
                actions: node.buttons.enumerated().map { i, b in
                    let opts: UNNotificationActionOptions = b.foreground == true ? [.foreground] : []
                    let aid = "\(i):\(b.tag)"
                    let icon = b.icon.map { UNNotificationActionIcon(systemImageName: $0) }
                    return b.input == true
                        ? UNTextInputNotificationAction(identifier: aid, title: b.title, options: opts, icon: icon,
                                                        textInputButtonTitle: "Gönder", textInputPlaceholder: "")
                        : UNNotificationAction(identifier: aid, title: b.title, options: opts, icon: icon)
                },
                intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: content.placeholder, options: [])
        }
        center.setNotificationCategories(Set(cats))
    }

    /// Planlı bildirimlerin tamamını yenisiyle değiştirir (takip bildirimlerine dokunmaz).
    func apply(_ items: [PlannedItem], cache: PhotoCache) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("plan-") })
        for it in items {
            let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: it.date)
            try? await center.add(UNNotificationRequest(
                identifier: it.id,
                content: body(it.text, node: it.nodeId, itemId: it.id, questIndex: it.questIndex, depth: 1,
                              title: it.title, thread: Self.thread(it.id), photo: it.photoId.flatMap(cache.fileURL)),
                trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
    }

    /// Takip, kökün başlığını ve grubunu taşır.
    func send(_ f: FollowUp, itemId: String, title: String?, thread: String?, photoURL: URL?, after seconds: TimeInterval = 3) async {
        try? await center.add(UNNotificationRequest(
            identifier: "fu-\(UUID().uuidString)",
            content: body(f.text, node: f.nodeId, itemId: itemId, questIndex: f.questIndex, depth: f.depth,
                          title: title, thread: thread, photo: photoURL),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
    }

    /// "plan-20261110-i3" → "plan-20261110": bir günün bildirimleri tek grupta.
    static func thread(_ id: String) -> String { id.split(separator: "-").prefix(2).joined(separator: "-") }

    private func body(_ text: String, node: String, itemId: String, questIndex: Int?, depth: Int,
                      title: String?, thread: String?, photo: URL?) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.body = text; c.sound = .default; c.categoryIdentifier = node
        c.title = title ?? ""; c.subtitle = gists[node] ?? ""
        if let t = thread { c.threadIdentifier = t }
        var info: [String: Any] = ["itemId": itemId, "nodeId": node, "depth": depth]
        if let q = questIndex { info["questIndex"] = q }
        if let t = title { info["title"] = t }
        if let t = thread { info["thread"] = t }
        c.userInfo = info
        // iOS eki kendi deposuna taşır: kopya verilir. Hata olursa bildirim eksiz gider, asla düşmez.
        if let src = photo {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            if (try? FileManager.default.copyItem(at: src, to: tmp)) != nil,
               let a = try? UNNotificationAttachment(identifier: "foto", url: tmp, options: nil) {
                c.attachments = [a]
            }
        }
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
