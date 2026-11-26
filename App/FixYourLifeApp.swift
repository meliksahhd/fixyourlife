import SwiftUI
import UserNotifications
import BackgroundTasks
import FYLCore

enum AppTab: Hashable { case summary, entries, wishes, calendar }

@MainActor final class AppModel: ObservableObject {
    /// Bildirime dokunma uygulamayı başlattığında da (ekran çizilmeden) var olmalı.
    static let shared = AppModel()
    static let refreshTaskId = "com.meliksahhd.fixyourlife.refresh"

    @Published var state: AppState { didSet { Theme.current = state.settings.theme } }
    @Published var rates: RatesSnapshot?
    @Published var ratesFailed = false
    @Published var tab: AppTab = .summary
    @Published var importMessage: String?
    let notifier = Notifier()
    private static func file(_ name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }
    private let url = AppModel.file("state.json"), ratesURL = AppModel.file("rates.json")

    /// false: state.json var ama okunamadı (yeniden başlatma sonrası kilit açılmadan). Bu durumda hiçbir şey
    /// kaydedilmez ve planlanmaz, yoksa gerçek verinin üzerine boş durum yazılır. Uygulama öne gelince yeniden denenir.
    private var loaded_: Bool
    private var applying: Task<Void, Never>?

    private init() {
        let loaded = Store.load(url)
        state = loaded ?? AppState(); loaded_ = loaded != nil
        Theme.current = state.settings.theme   // init'te didSet çalışmaz
        rates = (try? Data(contentsOf: ratesURL)).flatMap(parseRates)
        notifier.model = self
        UNUserNotificationCenter.current().delegate = notifier
    }

    func save() {
        guard loaded_ else { return }
        do { try Store.save(state, to: url) } catch { print("state.json kaydedilemedi: \(error)") }
    }

    func update(_ change: (inout AppState) -> Void) {
        guard loaded_ else { return }
        change(&state)
        save()
        reschedule()
    }

    /// Hediye maddelerini ekler ve bildirimleri yeniden kurar. iOS çağrıları sırayla yapılır (önceki bitmeden yenisi başlamaz).
    func reschedule() {
        guard reloadIfNeeded() else { return }
        let now = Date()
        state.addGiftWishes(now: now, calendar: .current)
        save()
        let rs = reminders(state.events, now: now, minuteOfDay: state.settings.calendarMinute, calendar: .current)
        let noon = state.settings.wishReminder ? noonBody(state.wishes) : nil, minute = state.settings.wishMinute
        let previous = applying
        applying = Task { [notifier] in
            await previous?.value
            await notifier.apply(reminders: rs, noon: noon, noonMinute: minute)
        }
    }

    /// Arka plan yenilemesi: iOS askıya almadan bildirimler kurulmuş olsun.
    func backgroundRefresh() async {
        scheduleRefresh()
        reschedule()
        await applying?.value
    }

    func refreshRates() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://finans.truncgil.com/v4/today.json")!)
            guard let r = parseRates(data) else { throw URLError(.cannotParseResponse) }
            rates = r; ratesFailed = false
            try? FileManager.default.createDirectory(at: ratesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: ratesURL, options: .atomic)
        } catch { ratesFailed = true }
    }

    func scheduleRefresh() {
        let r = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    /// Bildirime dokununca ilgili sekme.
    func open(_ name: String?) {
        switch name {
        case "wishes": tab = .wishes
        case "calendar": tab = .calendar
        default: break
        }
    }

    /// Ziraat Mobil → Hesap Hareketleri → Paylaş → Excel. Yanlış dosya: hiçbir şey eklenmez, nedeni söylenir.
    func importBank(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let xml = zipEntry(data, where: { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }, inflate: inflateRaw),
              let rows = ziraatRows(parseSheet(xml), calendar: .current), !rows.isEmpty
        else { importMessage = "Bu dosya Ziraat hesap hareketleri gibi görünmüyor"; return }
        var result: ImportResult?
        update { result = $0.importBank(rows, calendar: .current) }
        guard let r = result else { return }
        importMessage = "\(r.added) yeni hareket eklendi · \(r.skipped) atlandı · \(r.duplicates) zaten vardı"
        tab = .entries
    }

    private func reloadIfNeeded() -> Bool {
        if !loaded_, let s = Store.load(url) { state = s; loaded_ = true }
        return loaded_
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

    var body: some Scene {
        WindowGroup {
            TabView(selection: $model.tab) {
                SummaryView().tabItem { Label("Özet", systemImage: "chart.pie") }.tag(AppTab.summary)
                EntriesView().tabItem { Label("Hareketler", systemImage: "list.bullet") }.tag(AppTab.entries)
                WishesView().tabItem { Label("Alınacaklar", systemImage: "cart") }.tag(AppTab.wishes)
                CalendarView().tabItem { Label("Takvim", systemImage: "calendar") }.tag(AppTab.calendar)
            }
            .environmentObject(model)
            .environment(\.locale, Locale(identifier: "tr_TR"))
            .preferredColorScheme(model.state.settings.theme.isLight ? .light : .dark)
            .tint(Theme.tint)
            .onOpenURL { model.importBank($0) }
            .alert(model.importMessage ?? "", isPresented: Binding(get: { model.importMessage != nil },
                                                                   set: { if !$0 { model.importMessage = nil } })) {
                Button("Tamam") {}
            }
        }
        .onChange(of: phase, initial: true) { _, p in
            if p == .active {
                // İzin önce: ilk açılışta sistem sorar, sonra bildirimler kurulur.
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    model.reschedule()
                }
                Task { await model.refreshRates() }
            } else if p == .background {
                model.save()
                model.scheduleRefresh()
            }
        }
        .backgroundTask(.appRefresh(AppModel.refreshTaskId)) {
            await AppModel.shared.backgroundRefresh()
        }
    }
}
