import SwiftUI
import UserNotifications
import BackgroundTasks
import FYLCore

@MainActor final class AppModel: ObservableObject {
    /// Bildirim aksiyonu uygulamayı arka planda başlattığında da (ekran çizilmeden) var olmalı.
    static let shared = AppModel()

    @Published var state: AppState
    let content: Content
    let notifier = Notifier()
    let photos = PhotoCache()
    static let photoTaskId = "com.meliksahhd.fixyourlife.photos"
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
        let items = assignPhotos(plan(now: now, state: state, content: content, calendar: .current),
                                 previous: state.lastPlan, available: photos.available(), shown: shownPhotos(state))
        state.lastPlan = items
        save()
        let previous = applying
        applying = Task { [notifier, photos] in await previous?.value; await notifier.apply(items, cache: photos) }
    }

    @Published private(set) var photoKey = Keychain.get("unsplashKey") != nil

    /// nil siler. Fotoğraflar önbellekte kalır; yalnızca yenileri gelmez.
    func setPhotoKey(_ key: String?) {
        Keychain.set("unsplashKey", key)
        photoKey = key != nil
        if key != nil { Task { await refreshPhotos() } }
    }

    private var refreshing = false

    /// Önbelleği doldurur (ön plan ve arka plan yenilemesi). Anahtar yoksa ya da ağ hatasında sessizce durur.
    func refreshPhotos() async {
        guard !refreshing, reloadIfNeeded(), let key = Keychain.get("unsplashKey") else { return }
        refreshing = true; defer { refreshing = false }
        let client = UnsplashClient(key: key), target = 3, defaults = UserDefaults.standard
        var queries = content.nodes.compactMapValues(\.imageQueries)
        if state.setupDate != nil {
            for (g, group) in content.protocolMorning.enumerated() { if let q = group.imageQueries { queries["setup.\(g)"] = q } }
        }
        let shown = shownPhotos(state)
        let reserved = reservedPhotos(state.lastPlan)
            .union(state.setupNotes.filter { $0.key.hasPrefix("foto.") }.map(\.value))
        var avail = photos.available(), changed = false
        let order = refillOrder(queries: queries, available: avail, shown: shown, reserved: reserved, target: target, budget: 10)
        nodes: for node in order {
            guard let q = queries[node]?.randomElement() else { continue }
            var need = target - (avail[node] ?? []).filter { !shown.contains($0) && !reserved.contains($0) }.count
            let pageKey = "unsplashPage.\(node)", page = max(defaults.integer(forKey: pageKey), 1)
            let results: [UnsplashPhoto]
            do { results = try await client.search(q, page: page) } catch { break nodes }   // 401/403/429 ya da ağ: sonraki sefere
            let cached = Set(avail.values.joined())
            let fresh = results.filter { !shown.contains($0.id) && !cached.contains($0.id) }
            // Sayfa tükendiyse sıradaki sefer bir sonraki sayfa; boş sayfa = sonuçların sonu, başa dön.
            if results.isEmpty { defaults.set(1, forKey: pageKey) } else if fresh.count <= need { defaults.set(page + 1, forKey: pageKey) }
            for p in fresh where need > 0 {
                guard (try? await photos.store(p, nodeId: node, client: client)) != nil else { continue }
                need -= 1; changed = true
            }
            avail = photos.available()
        }
        let old = prunable(cached: Array(avail.values.joined()), reserved: reserved, shown: shown)
        photos.remove(old)
        if changed || !old.isEmpty { replan() }
    }

    /// Kurulum sorusunun fotoğrafı: bir kez seçilir ve `setupNotes["foto.<key>"]`de kalır (geri dönünce aynısı).
    func setupPhoto(key: String, group: Int) -> String? {
        let k = "foto.\(key)"
        if let id = state.setupNotes[k], photos.fileURL(id) != nil { return id }
        let used = Set(state.setupNotes.filter { $0.key.hasPrefix("foto.") }.map(\.value))
        guard let id = photos.available()["setup.\(group)"]?.first(where: { !used.contains($0) }) else { return nil }
        state.setupNotes[k] = id; save()
        return id
    }

    func schedulePhotoRefresh() {
        let r = BGAppRefreshTaskRequest(identifier: Self.photoTaskId)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(r)
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
        if let f = handle(reply, at: Date(), content: content, state: &state, rng: &rng) {
            // Ağ yok: önbellekten. itemId nil: handle() kök tarihini itemId ile arar, takip olayı onu gölgelememeli.
            let photo = pickFollowUpPhoto(nodeId: f.nodeId, available: photos.available(),
                                          shown: shownPhotos(state), reserved: reservedPhotos(state.lastPlan))
            if let p = photo { state.events.append(Event(date: Date(), kind: .sent, nodeId: f.nodeId, text: f.text, itemId: nil, photoId: p)) }
            await notifier.send(f, itemId: itemId, title: info["title"] as? String, thread: info["thread"] as? String,
                                photoURL: photo.flatMap(photos.fileURL))
        }
        replan()
        await applying?.value
    }

    /// Ayarlardaki "Test bildirimi": takipli + metin girişli bir dalı olan kesinti 60 sn sonra gelir.
    /// Bildirimlerin, butonların ve takiplerin cihazda çalıştığını kontrol etmek için. Durumu değiştirmez.
    func sendTestInterrupt() {
        guard let text = content.nodes["i_alive"]?.texts.lazy.compactMap({ render($0, profile: self.state.profile, questIndex: nil) }).first
        else { return }
        let photo = photos.available()["i_alive"]?.first.flatMap(photos.fileURL)
        Task { [notifier] in
            await notifier.send(FollowUp(nodeId: "i_alive", text: text, questIndex: nil, depth: 1),
                                itemId: "test-\(Int(Date().timeIntervalSince1970))", title: "Kesinti · test", thread: "test",
                                photoURL: photo, after: 60)
        }
    }
}

@main
struct FixYourLifeApp: App {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var phase

    init() {
        _ = AppModel.shared   // delegate'i uygulama açılırken ata
        // Gezinme başlıkları serif (New York).
        let serif = { (style: UIFont.TextStyle) -> UIFont in
            let base = UIFont.preferredFont(forTextStyle: style).fontDescriptor
            return UIFont(descriptor: base.withDesign(.serif) ?? base, size: 0)
        }
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: serif(.largeTitle)]
        UINavigationBar.appearance().titleTextAttributes = [.font: serif(.headline)]
    }

    /// Protokol yeniden çalışıyorsa (profil var), kurulum günü gelince kurulum ekranı açılır; o güne kadar tahta.
    private var isSetupDay: Bool {
        guard let s = model.state.setupDate else { return false }
        return Calendar.current.startOfDay(for: s) <= logicalDay(Date(), calendar: .current)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.state.profile == nil || isSetupDay { SetupView() } else { BoardView() }
            }
            .environmentObject(model)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
        .onChange(of: phase, initial: true) { _, p in
            if p == .active {
                model.replan()
                Task { await model.refreshPhotos() }
            } else if p == .background {
                model.save()
                model.schedulePhotoRefresh()
            }
        }
        .backgroundTask(.appRefresh(AppModel.photoTaskId)) {
            await AppModel.shared.schedulePhotoRefresh()
            await AppModel.shared.refreshPhotos()
        }
    }
}
