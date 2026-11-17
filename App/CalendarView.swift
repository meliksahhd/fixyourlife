import SwiftUI
import FYLCore

struct CalendarView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: CalEvent?
    @State private var adding = false

    var body: some View {
        let now = Date()
        let days = model.state.events.reduce(into: [UUID: Int]()) { $0[$1.id] = daysUntil($1, now: now, calendar: .current) }
        let upcoming = model.state.events.filter { days[$0.id] != nil }.sorted { days[$0.id]! < days[$1.id]! }
        let past = model.state.events.filter { days[$0.id] == nil }.sorted { $0.date > $1.date }
        NavigationStack {
            List {
                ForEach(upcoming) { e in row(e, countdownText(days[e.id]!)) }
                if !past.isEmpty {
                    Section("Geçmiş") {
                        ForEach(past) { e in
                            row(e, e.date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))
                        }
                    }
                }
            }
            .themedForm()
            .navigationTitle("Takvim")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { EventForm(event: nil).environmentObject(model) }
            .sheet(item: $editing) { EventForm(event: $0).environmentObject(model) }
        }
    }

    private func row(_ e: CalEvent, _ trailing: String) -> some View {
        Button { editing = e } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name).foregroundStyle(Theme.text)
                    Text(e.kind.title).font(.caption).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Text(trailing).font(.subheadline).foregroundStyle(Theme.tint)
            }
        }
        .listRowBackground(Theme.card)
        .swipeActions {
            Button("Sil", role: .destructive) { model.update { $0.events.removeAll { $0.id == e.id } } }
        }
    }
}

/// Yeni olay ya da düzenleme. Tür değişince hatırlatmalar ve tekrar türün varsayılanına döner.
struct EventForm: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let event: CalEvent?
    @State private var name: String
    @State private var kind: EventKind
    @State private var date: Date
    @State private var timed: Bool
    @State private var minute: Int
    @State private var yearly: Bool
    @State private var leadDays: Set<Int>
    @State private var gift: Bool

    init(event: CalEvent?) {
        self.event = event
        let k = event?.kind ?? .birthday
        _name = State(initialValue: event?.name ?? "")
        _kind = State(initialValue: k)
        _date = State(initialValue: event?.date ?? Date())
        _timed = State(initialValue: event?.minute != nil)
        _minute = State(initialValue: event?.minute ?? 540)
        _yearly = State(initialValue: event?.yearly ?? CalEvent.defaultYearly(k))
        _leadDays = State(initialValue: Set(event?.leadDays ?? CalEvent.defaultLeadDays(k)))
        _gift = State(initialValue: event?.gift ?? false)
    }

    private var timedKind: Bool { kind == .exam || kind == .task }
    private var giftKind: Bool { kind == .birthday || kind == .special }
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Örn. Annemin doğum günü", text: $name)
                Picker("Tür", selection: $kind) {
                    ForEach(EventKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .onChange(of: kind) { _, k in
                    leadDays = Set(CalEvent.defaultLeadDays(k)); yearly = CalEvent.defaultYearly(k)
                }
                DatePicker("Tarih", selection: $date, displayedComponents: .date)
                if timedKind {
                    Toggle("Saat belli", isOn: $timed)
                    if timed { DatePicker("Saat", selection: minuteBinding($minute), displayedComponents: .hourAndMinute) }
                }
                if kind == .other { Toggle("Her yıl", isOn: $yearly) }
                if giftKind { Toggle("Hediye al", isOn: $gift) }
                Section {
                    ForEach(CalEvent.leadOptions, id: \.self) { n in
                        Button { leadDays.formSymmetricDifference([n]) } label: {
                            HStack {
                                Text(n == 0 ? "O gün" : "\(n) gün önce").foregroundStyle(Theme.text)
                                Spacer()
                                if leadDays.contains(n) { Image(systemName: "checkmark").foregroundStyle(Theme.tint) }
                            }
                        }
                    }
                } header: {
                    Text("Hatırlatma")
                } footer: {
                    if leadDays.isEmpty { Text("En az bir hatırlatma seç.") }
                }
            }
            .themedForm()
            .navigationTitle(event == nil ? "Yeni olay" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).disabled(trimmed.isEmpty || leadDays.isEmpty)
                }
            }
        }
    }

    private func save() {
        var e = event ?? CalEvent(name: "", kind: kind, date: date, yearly: yearly, leadDays: [])
        e.name = trimmed; e.kind = kind; e.date = Calendar.current.startOfDay(for: date)
        e.minute = timedKind && timed ? minute : nil
        e.yearly = yearly; e.leadDays = leadDays.sorted(by: >); e.gift = giftKind && gift
        model.update { s in
            if let i = s.events.firstIndex(where: { $0.id == e.id }) { s.events[i] = e } else { s.events.append(e) }
        }
        dismiss()
    }
}

/// Günün dakikası (540 = 09:00) ↔ saat seçici.
func minuteBinding(_ m: Binding<Int>) -> Binding<Date> {
    Binding(get: { Calendar.current.date(bySettingHour: m.wrappedValue / 60, minute: m.wrappedValue % 60, second: 0, of: Date())! },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); m.wrappedValue = c.hour! * 60 + c.minute! })
}
