import SwiftUI
import UserNotifications
import FYLCore

/// Kurulum günü: karşılama → (bekleme) → sabah protokolü → gün içi → akşam sentezi.
/// İlerleme ve taslaklar `setupNotes`'ta durur, uygulama kapansa da kaybolmaz.
struct SetupView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            let today = logicalDay(Date(), calendar: .current)
            if let s = model.state.setupDate.map({ Calendar.current.startOfDay(for: $0) }) {
                if s <= today { SetupDayView() } else { WaitingView(day: s) }
            } else {
                WelcomeView()
            }
        }
    }
}

extension AppModel {
    func note(_ key: String) -> Binding<String> {
        Binding(get: { self.state.setupNotes[key] ?? "" }, set: { self.state.setupNotes[key] = $0 })
    }
    /// Kurulum gününü planlar; yeni protokol eski notlardan temiz başlar. Eski profil, sentez kaydedilene kadar kalır.
    func scheduleSetup(_ date: Date) {
        state.setupDate = Calendar.current.startOfDay(for: date)
        state.setupNotes = [:]
        replan()
    }
}

private func trimmed(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

// MARK: - Karşılama

private struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))! }

    var body: some View {
        Form {
            Section {
                Text("Bir günde hayatını yeniden kurmak için bir protokol. Sabah kazı, gün boyu kesinti soruları, akşam sentez. Sonra her gün bir oyun gibi oynarsın.")
            }
            Section("1. Bildirimler") {
                Text("Sorular bildirim olarak gelir ve butonlarla cevaplanır.")
                Button("Bildirimlere izin ver") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
            Section("2. Kilit ekranı") {
                Text("Cevapların kişisel. Kilit ekranında yalnızca \"\(model.content.placeholder)\" görünsün: Ayarlar → Bildirimler → FixYourLife → Önizlemeleri Göster → Kilit Açıkken.")
                Button("Bildirim ayarlarını aç") {
                    if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
                }
            }
            Section("3. Kurulum günü") {
                Text("Bütün bir gün ayır. Sabah yaklaşık bir saat, gün içinde birkaç dakikalık sorular, akşam 20 dakika.")
                DatePicker("Gün", selection: $date, in: tomorrow..., displayedComponents: .date)
                Button(Calendar.current.isDate(date, inSameDayAs: tomorrow) ? "Yarın sabah başla" : "Bu gün başla") {
                    model.scheduleSetup(date)
                }
                .bold()
            }
        }
        .themedForm()
        .navigationTitle("FixYourLife")
    }
}

private struct WaitingView: View {
    @EnvironmentObject var model: AppModel
    let day: Date

    var body: some View {
        Form {
            Section {
                Text("Kurulum günün: \(day.formatted(.dateTime.day().month(.wide).weekday(.wide)))")
                    .font(.headline)
                Text("O sabah uygulamayı aç. Kâğıt ve kalem hazır olsun. Gün boyu sorular bildirimle gelecek.")
            }
            Section {
                Button("Tarihi değiştir") { model.state.setupDate = nil; model.replan() }
            }
        }
        .themedForm()
        .navigationTitle("Hazırlan")
    }
}

// MARK: - Kurulum günü

private struct SetupDayView: View {
    @EnvironmentObject var model: AppModel

    private var questions: [(key: String, gi: Int, group: String, text: String)] {
        model.content.protocolMorning.enumerated().flatMap { g, group in
            group.questions.enumerated().map { q, text in (key: "\(g).\(q)", gi: g, group: group.title, text: text) }
        }
    }
    private var step: Int { Int(model.state.setupNotes["adim"] ?? "") ?? 0 }
    private func go(_ s: Int) { model.state.setupNotes["adim"] = String(max(0, s)); model.save() }

    var body: some View {
        let qs = questions
        Group {
            if step < qs.count {
                QuestionView(index: step, total: qs.count, item: qs[step], next: { go(step + 1) }, back: step > 0 ? { go(step - 1) } : nil)
            } else if step == qs.count {
                IdentityView(next: { go(step + 1) }, back: { go(step - 1) })
            } else if step == qs.count + 1 {
                DayView(next: { go(step + 1) }, back: { go(step - 1) })
            } else {
                SynthesisView(back: { go(step - 1) })
            }
        }
    }
}

private struct QuestionView: View {
    @EnvironmentObject var model: AppModel
    let index: Int, total: Int
    let item: (key: String, gi: Int, group: String, text: String)
    let next: () -> Void
    let back: (() -> Void)?
    @State private var photo: String?

    /// İlk "?"a kadarı soru, sonrası (varsa) italik açıklama.
    private var parts: (question: String, aside: String?) {
        guard let q = item.text.firstIndex(of: "?") else { return (item.text, nil) }
        let rest = item.text[item.text.index(after: q)...].trimmingCharacters(in: .whitespaces)
        return (String(item.text[...q]), rest.isEmpty ? nil : rest)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PhotoHeader(photoId: photo, height: 280)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("Sabah · \(item.group)", color: Theme.accent)
                        Spacer()
                        Text("\(index + 1) / \(total)").font(.footnote).monospacedDigit().foregroundStyle(Theme.secondary)
                    }
                    ProgressView(value: Double(index + 1), total: Double(total)).tint(Theme.text)
                    Text(parts.question).font(.system(.title, design: .serif)).padding(.top, 28)
                    if let aside = parts.aside {
                        Text(aside).font(.system(.title3, design: .serif)).italic().foregroundStyle(Theme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kısa not (isteğe bağlı)").font(.caption).foregroundStyle(Theme.secondary)
                        TextField("Bir iki kelime…", text: model.note(item.key), axis: .vertical)
                        Theme.line.frame(height: 1)
                    }
                    .padding(.top, 28)
                    Text("Kâğıda yaz. Asıl iş, düşünmenin kendisi.")
                        .font(.footnote).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity).padding(.top, 32)
                    Button("Kâğıda yazdım", action: next).buttonStyle(PrimaryButtonStyle())
                    if let back {
                        Button("Geri", action: back).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(24)
            }
        }
        .foregroundStyle(Theme.text)
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: item.key) { photo = model.setupPhoto(key: item.key, group: item.gi) }
    }
}

private struct IdentityView: View {
    @EnvironmentObject var model: AppModel
    let next: () -> Void, back: () -> Void

    var body: some View {
        Form {
            Section("Kimlik cümlesi") {
                Text("Ben … tipte biriyim.")
                TextField("örn. her gün üreten", text: model.note("kimlik"), axis: .vertical)
            }
            Section {
                Button("Devam", action: next).bold().disabled(trimmed(model.state.setupNotes["kimlik"]).isEmpty)
                Button("Geri", action: back)
            }
        }
        .themedForm()
        .navigationTitle("Sabah protokolü")
    }
}

private struct DayView: View {
    let next: () -> Void, back: () -> Void

    var body: some View {
        Form {
            Section {
                Text("Sabah bitti. Gün boyu sorular bildirimle gelecek. Kâğıdın yanında olsun, cevaplarken bir an dur ve düşün.")
                Text("Akşam 22:00'de sentez hatırlatması gelir.").foregroundStyle(.secondary)
            }
            Section {
                Button("Sentezi şimdi aç", action: next).bold()
                Button("Geri", action: back)
            }
        }
        .themedForm()
        .navigationTitle("Gün içi")
    }
}

private struct SynthesisView: View {
    @EnvironmentObject var model: AppModel
    let back: () -> Void

    private static let required = ["s.enemy", "s.antiVision", "s.vision", "s.yearGoal", "s.monthProject", "kimlik"]
    private var notes: [String: String] { model.state.setupNotes }
    private func list(_ prefix: String) -> [String] { (0..<3).map { trimmed(notes["\(prefix).\($0)"]) }.filter { !$0.isEmpty } }
    private var ready: Bool { Self.required.allSatisfy { !trimmed(notes[$0]).isEmpty } && !list("s.quest").isEmpty }

    var body: some View {
        Form {
            Section("Neden takıldım (isteğe bağlı)") { TextField("En doğru gelen sebep", text: model.note("s.whyStuck"), axis: .vertical) }
            Section("Asıl düşman *") { TextField("İçsel kalıp ya da inanç", text: model.note("s.enemy"), axis: .vertical) }
            Section("Anti-vizyon *") { TextField("Reddettiğin hayat, tek cümle", text: model.note("s.antiVision"), axis: .vertical) }
            Section("Vizyon *") { TextField("Kurduğun hayatın ilk hâli, tek cümle", text: model.note("s.vision"), axis: .vertical) }
            Section("Kimlik *") { TextField("Ben … tipte biriyim", text: model.note("kimlik"), axis: .vertical) }
            Section("1 yıl *") { TextField("Bir yıl sonra olmuş olacak tek somut şey", text: model.note("s.yearGoal"), axis: .vertical) }
            Section("1 ay projesi (boss) *") { TextField("30 günde bitecek proje", text: model.note("s.monthProject"), axis: .vertical) }
            Section("Günlük görevler (en az 1) *") {
                ForEach(0..<3, id: \.self) { i in TextField("Görev \(i + 1)", text: model.note("s.quest.\(i)")) }
            }
            Section("Kısıtlar (feda etmeyeceklerin)") {
                ForEach(0..<3, id: \.self) { i in TextField("Kısıt \(i + 1)", text: model.note("s.constraint.\(i)")) }
            }
            Section {
                Button("Oyunu başlat", action: save).bold().disabled(!ready)
                Button("Geri", action: back)
            }
        }
        .themedForm()
        .navigationTitle("Akşam sentezi")
        .onAppear(perform: prefill)
    }

    /// Protokol yeniden çalışıyorsa eski profil taslak olarak gelir.
    private func prefill() {
        guard let p = model.state.profile, notes["s.enemy"] == nil else { return }
        let old = ["s.whyStuck": p.whyStuck, "s.enemy": p.enemy, "s.antiVision": p.antiVision, "s.vision": p.vision,
                   "s.yearGoal": p.yearGoal, "s.monthProject": p.monthProject]
        for (k, v) in old { model.state.setupNotes[k] = v }
        if trimmed(notes["kimlik"]).isEmpty { model.state.setupNotes["kimlik"] = p.identity }
        for (i, q) in p.quests.prefix(3).enumerated() { model.state.setupNotes["s.quest.\(i)"] = q }
        for (i, c) in p.constraints.prefix(3).enumerated() { model.state.setupNotes["s.constraint.\(i)"] = c }
    }

    private func save() {
        let today = logicalDay(Date(), calendar: .current)
        model.state.profile = Profile(
            identity: trimmed(notes["kimlik"]), antiVision: trimmed(notes["s.antiVision"]), vision: trimmed(notes["s.vision"]),
            enemy: trimmed(notes["s.enemy"]), yearGoal: trimmed(notes["s.yearGoal"]), monthProject: trimmed(notes["s.monthProject"]),
            whyStuck: trimmed(notes["s.whyStuck"]), quests: list("s.quest"), constraints: list("s.constraint"), monthStart: today)
        model.state.loopStart = Calendar.current.date(byAdding: .day, value: 1, to: today)
        model.state.setupDate = nil
        model.state.setupNotes["adim"] = nil
        model.replan()
    }
}
