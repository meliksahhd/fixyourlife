import SwiftUI
import UserNotifications
import FYLCore

/// Oyun tahtası (spec §6.2): makalenin 6 bileşeni + kimlik ve düşman. Her alan dokununca düzenlenir.
struct BoardView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var editing: Field?
    @State private var showSettings = false
    @State private var notificationsOff = false

    enum Field: String, Identifiable {
        case vision, antiVision, yearGoal, monthProject, quests, constraints, identity, enemy
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            if let p = model.state.profile {
                List {
                    if notificationsOff {
                        Section {
                            Label("Bildirimler kapalı. Sorular gelmez.", systemImage: "bell.slash").foregroundStyle(.red)
                            Button("Bildirim ayarlarını aç", action: openNotificationSettings)
                        }
                    }
                    row("Kimlik", "Ben \(p.identity) tipte biriyim.", .identity)
                    row("Kazanma koşulu", p.vision, .vision)
                    row("Risk", p.antiVision, .antiVision)
                    row("Ana görev · 1 yıl", p.yearGoal, .yearGoal)
                    Section("Boss · 1 ay") {
                        Button { editing = .monthProject } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.monthProject)
                                Text("\(daysLeft(p)) gün kaldı").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                    Section("Bugünün görevleri") {
                        let status = questStatus(model.state, on: logicalDay(Date(), calendar: .current), calendar: .current)
                        ForEach(Array(p.quests.enumerated()), id: \.offset) { i, q in
                            Button { tap(i, current: status.indices.contains(i) ? status[i] : nil) } label: {
                                HStack {
                                    Image(systemName: Self.icon(status.indices.contains(i) ? status[i] : nil))
                                    Text(q)
                                }
                            }
                            .tint(.primary)
                        }
                        Button("Görevleri düzenle") { editing = .quests }.font(.footnote)
                    }
                    row("Kurallar", p.constraints.isEmpty ? "Yok" : p.constraints.joined(separator: "\n"), .constraints)
                    row("Düşman", p.enemy, .enemy)
                }
                .navigationTitle("Oyun tahtası")
                .toolbar { Button { showSettings = true } label: { Image(systemName: "gearshape") } }
                .sheet(item: $editing) { EditSheet(field: $0) }
                .sheet(isPresented: $showSettings) { SettingsSheet() }
                .task(id: phase) { await checkNotifications() }
            }
        }
    }

    private func row(_ title: String, _ value: String, _ field: Field) -> some View {
        Section(title) { Button(value) { editing = field }.tint(.primary) }
    }

    private func daysLeft(_ p: Profile) -> Int {
        let cal = Calendar.current
        let passed = cal.dateComponents([.day], from: cal.startOfDay(for: p.monthStart), to: logicalDay(Date(), calendar: cal)).day ?? 0
        return max(0, 30 - passed)
    }

    // boş → yaptım → kısmen → yapmadım → boş
    static let cycle: [String?: String] = [nil: "yaptim", "bos": "yaptim", "yaptim": "kismen", "kismen": "yapmadim", "yapmadim": "bos"]
    static func icon(_ tag: String?) -> String {
        switch tag { case "yaptim": "checkmark.circle.fill"; case "kismen": "circle.lefthalf.filled"; case "yapmadim": "xmark.circle"; default: "circle" }
    }

    private func tap(_ i: Int, current: String?) {
        model.state.events.append(Event(date: Date(), kind: .answered, nodeId: "board", tag: Self.cycle[current] ?? "yaptim", questIndex: i))
        model.save()
    }

    private func checkNotifications() async {
        let center = UNUserNotificationCenter.current()
        var s = await center.notificationSettings()
        if s.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            s = await center.notificationSettings()
        }
        notificationsOff = !(s.authorizationStatus == .authorized || s.authorizationStatus == .provisional)
    }
}

func openNotificationSettings() {
    if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
}

private func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

// MARK: - Alan düzenleme

private struct EditSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let field: BoardView.Field
    @State private var text = ""
    @State private var items = ["", "", ""]

    private var isList: Bool { field == .quests || field == .constraints }
    private var valid: Bool {
        switch field {
        case .quests: !items.map(clean).filter { !$0.isEmpty }.isEmpty
        case .constraints: true
        default: !clean(text).isEmpty
        }
    }
    private var title: String {
        switch field {
        case .vision: "Kazanma koşulu (vizyon)"; case .antiVision: "Risk (anti-vizyon)"; case .yearGoal: "1 yıl"
        case .monthProject: "1 ay projesi (boss)"; case .quests: "Günlük görevler (en az 1)"; case .constraints: "Kısıtlar"
        case .identity: "Ben … tipte biriyim"; case .enemy: "Asıl düşman"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    if isList {
                        ForEach(0..<3, id: \.self) { i in TextField(field == .quests ? "Görev \(i + 1)" : "Kısıt \(i + 1)", text: $items[i]) }
                    } else {
                        TextField(title, text: $text, axis: .vertical)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: save).disabled(!valid) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let p = model.state.profile else { return }
        switch field {
        case .vision: text = p.vision; case .antiVision: text = p.antiVision; case .yearGoal: text = p.yearGoal
        case .monthProject: text = p.monthProject; case .identity: text = p.identity; case .enemy: text = p.enemy
        case .quests: for (i, q) in p.quests.prefix(3).enumerated() { items[i] = q }
        case .constraints: for (i, c) in p.constraints.prefix(3).enumerated() { items[i] = c }
        }
    }

    private func save() {
        guard var p = model.state.profile else { return }
        let t = clean(text), list = items.map(clean).filter { !$0.isEmpty }
        switch field {
        case .vision: p.vision = t; case .antiVision: p.antiVision = t; case .yearGoal: p.yearGoal = t
        case .monthProject: p.monthProject = t; case .identity: p.identity = t; case .enemy: p.enemy = t
        case .quests: p.quests = list
        case .constraints: p.constraints = list
        }
        model.state.profile = p
        model.replan()
        dismiss()
    }
}

// MARK: - Ayarlar

private struct SettingsSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var morning = Date()
    @State private var evening = Date()
    @State private var setupDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    @State private var testSent = false

    private static let f: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f }()
    private var morningText: String { Self.f.string(from: morning) }
    private var eveningText: String { Self.f.string(from: evening) }
    /// Sabah 04:00'ten (mantıksal gün başı) önce olamaz; akşam sabahtan sonra olmalı.
    private var timesValid: Bool { morningText >= "04:00" && eveningText > morningText }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Sabah", selection: $morning, displayedComponents: .hourAndMinute)
                    DatePicker("Akşam kapanışı", selection: $evening, displayedComponents: .hourAndMinute)
                    if !timesValid { Text("Sabah 04:00 ya da sonrası, akşam sabahtan sonra olmalı.").font(.footnote).foregroundStyle(.red) }
                    Button("Saatleri kaydet", action: saveTimes)
                        .disabled(!timesValid || (morningText == model.state.settings.morning && eveningText == model.state.settings.evening))
                } header: { Text("Saatler") } footer: { Text("Kesinti soruları sabahtan 1 saat sonra başlar, akşamdan 30 dk önce biter. Bu saatlerin dışında soru gelmez.") }

                Section {
                    DatePicker("Gün", selection: $setupDay, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    Button("Protokolü yeniden başlat") { model.scheduleSetup(setupDay); dismiss() }
                } header: { Text("Protokol") } footer: { Text("Seçtiğin gün kurulum günü olur. Yeni sentezi kaydedene kadar şimdiki tahtan geçerli kalır.") }

                Section {
                    Button(testSent ? "Gönderildi, 1 dk içinde gelir" : "Test bildirimi") { model.sendTestInterrupt(); testSent = true }
                        .disabled(testSent)
                    Button("Bildirim ayarlarını aç", action: openNotificationSettings)
                } header: { Text("Bildirimler") } footer: { Text("Test: 1 dakika sonra takipli bir soru gelir. Ana ekrana dönüp bekle.") }

                Section { LabeledContent("İçerik sürümü", value: "\(model.content.version)") }
            }
            .navigationTitle("Ayarlar")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } } }
            .onAppear {
                morning = Self.f.date(from: model.state.settings.morning).flatMap(todayAt) ?? morning
                evening = Self.f.date(from: model.state.settings.evening).flatMap(todayAt) ?? evening
            }
        }
    }

    private func todayAt(_ t: Date) -> Date? {
        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
        return Calendar.current.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: Date())
    }

    private func saveTimes() {
        model.state.settings.morning = morningText
        model.state.settings.evening = eveningText
        model.replan()
    }
}
