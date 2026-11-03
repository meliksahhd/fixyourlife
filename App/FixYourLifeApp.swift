import SwiftUI
import UserNotifications
import FYLCore

@MainActor final class AppModel: ObservableObject {
    /// Bildirim aksiyonu uygulamayı arka planda başlattığında da (ekran çizilmeden) var olmalı.
    static let shared = AppModel()

    @Published var state: AppState
    let content: Content
    let notifier = Notifier()
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("state.json")

    /// false: state.json var ama okunamadı (yeniden başlatma sonrası kilit açılmadan). Bu durumda hiçbir şey
    /// kaydedilmez ve planlanmaz, yoksa gerçek verinin üzerine boş durum yazılır. Uygulama öne gelince yeniden denenir.
    private var loaded_: Bool
    private var applying: Task<Void, Never>?

    private init() {
        guard let u = Bundle.main.url(forResource: "system", withExtension: "json"),
              let data = try? Data(contentsOf: u), let c = try? Content.load(data)
        else { fatalError("system.json yüklenemedi") }   // Task 3 testi gömülü içeriğin geçerliliğini garanti eder
        content = c
        let loaded = Store.load(url)
        state = loaded ?? AppState(); loaded_ = loaded != nil
        notifier.model = self
        notifier.registerCategories(c)
        UNUserNotificationCenter.current().delegate = notifier
    }

    func save() {
        guard loaded_ else { return }
        do { try Store.save(state, to: url) } catch { print("state.json kaydedilemedi: \(error)") }
    }

    /// Bildirimleri yeniden kurar. iOS çağrıları sırayla yapılır (önceki bitmeden yenisi başlamaz).
    func replan() {
        guard reloadIfNeeded() else { return }
        let now = Date()
        state.events += harvestSent(previous: state.lastPlan, now: now)
        let items = plan(now: now, state: state, content: content, calendar: .current)
        state.lastPlan = items
        save()
        let previous = applying
        applying = Task { [notifier] in await previous?.value; await notifier.apply(items) }
    }

    private func reloadIfNeeded() -> Bool {
        if !loaded_, let s = Store.load(url) { state = s; loaded_ = true }
        return loaded_
    }

    /// Bildirim butonu. Dokunma/kapatma ve tanınmayan aksiyonlar yok sayılır.
    /// Bildirim butonu. iOS arka plan süresini bitirmeden (completionHandler'dan önce) bildirimler kurulmuş olur.
    func receive(_ response: UNNotificationResponse) async {
        guard reloadIfNeeded() else { return }
        let info = response.notification.request.content.userInfo
        let parts = response.actionIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let i = Int(parts[0]),
              let itemId = info["itemId"] as? String, let nodeId = info["nodeId"] as? String,
              let buttons = content.nodes[nodeId]?.buttons, buttons.indices.contains(i), buttons[i].tag == parts[1]
        else { return }
        let reply = Reply(itemId: itemId, nodeId: nodeId, buttonIndex: i,
                          text: (response as? UNTextInputNotificationResponse)?.userText,
                          questIndex: info["questIndex"] as? Int, depth: info["depth"] as? Int ?? 1)
        var rng = SystemRandomNumberGenerator()
        if let f = handle(reply, at: Date(), content: content, state: &state, rng: &rng) { await notifier.send(f, itemId: itemId) }
        replan()
        await applying?.value
    }

    // GEÇİCİ test kancası (Task 7 doğrulaması; Task 8'de kaldırılır). Durumu değiştirmez:
    // örnek profille bir kesinti (takipli + metin girişli dal) 60 sn sonra gelir.
    func sendTestInterrupt() {
        let sample = Profile(identity: "Yaratıcı biri", antiVision: "Masa başında çürüyen", vision: "Kendi işini yapan",
                             enemy: "Onay ihtiyacı", yearGoal: "İlk ürün", monthProject: "Uygulamayı bitir", whyStuck: "",
                             quests: ["Oku", "Yaz"], constraints: ["Uyku"], monthStart: Date())
        guard let text = content.nodes["i_alive"]?.texts.lazy.compactMap({ render($0, profile: sample, questIndex: nil) }).first
        else { return }
        Task { await notifier.send(FollowUp(nodeId: "i_alive", text: text, questIndex: nil, depth: 1), itemId: "test-\(Int(Date().timeIntervalSince1970))", after: 60) }
    }
}

@main
struct FixYourLifeApp: App {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var phase

    init() { _ = AppModel.shared }   // delegate'i uygulama açılırken ata

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text("FixYourLife")
                if model.state.profile == nil {
                    Button("Test: örnek profil + 1 dk sonra kesinti") { model.sendTestInterrupt() }
                }
            }
        }
        .onChange(of: phase, initial: true) { _, p in
            if p == .active {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                model.replan()
            } else if p == .background {
                model.save()
            }
        }
    }
}
