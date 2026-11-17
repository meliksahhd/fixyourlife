import SwiftUI
import UniformTypeIdentifiers
import FYLCore

struct EntriesView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: Entry?
    @State private var importing = false

    var body: some View {
        let cal = Calendar.current
        let months = Dictionary(grouping: model.state.entries) { cal.dateInterval(of: .month, for: $0.date)!.start }
        NavigationStack {
            List {
                ForEach(months.keys.sorted(by: >), id: \.self) { m in
                    Section(m.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "tr_TR")))) {
                        ForEach(months[m]!.sorted { $0.date > $1.date }) { e in
                            Button { editing = e } label: { row(e) }
                                .listRowBackground(Theme.card)
                                .swipeActions {
                                    Button("Sil", role: .destructive) { model.update { $0.entries.removeAll { $0.id == e.id } } }
                                }
                        }
                    }
                }
            }
            .themedForm()
            .navigationTitle("Hareketler")
            .toolbar { Button("İçe aktar") { importing = true } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "xlsx")!]) { r in
                if case .success(let u) = r { model.importBank(u) }
            }
            .sheet(item: $editing) { EntryForm(entry: $0).environmentObject(model) }
        }
    }

    private func row(_ e: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.state.category(e.categoryId)?.name ?? "Diğer").foregroundStyle(Theme.text)
                if !e.note.isEmpty { Text(e.note).font(.caption).foregroundStyle(Theme.secondary).lineLimit(1) }
            }
            Spacer()
            Text((e.flow == .income ? "+" : "") + formatTL(e.amount)).monospacedDigit()
                .foregroundStyle(e.flow == .income ? Theme.up : Theme.text)
        }
    }
}

/// Yeni kayıt ya da düzenleme. İçe aktarılmış kayıtta tutar, tarih ve tür bankadan gelir (salt okunur);
/// kategori değişince işyeri kuralı öğrenilir.
struct EntryForm: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let entry: Entry?
    @State private var flow: Flow
    @State private var amount: String
    @State private var categoryId: String
    @State private var note: String
    @State private var date: Date
    @FocusState private var focused: Bool

    init(entry: Entry?) {
        self.entry = entry
        _flow = State(initialValue: entry?.flow ?? .expense)
        _amount = State(initialValue: entry.map { formatTL($0.amount).replacingOccurrences(of: " ₺", with: "") } ?? "")
        _categoryId = State(initialValue: entry?.categoryId ?? Category.otherExpense)
        _note = State(initialValue: entry?.note ?? "")
        _date = State(initialValue: entry?.date ?? Date())
    }

    private var imported: Bool { entry?.bankKey != nil }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tür", selection: $flow) {
                    Text("Gider").tag(Flow.expense)
                    Text("Gelir").tag(Flow.income)
                }
                .pickerStyle(.segmented).disabled(imported)
                .onChange(of: flow) { _, f in
                    if model.state.category(categoryId)?.flow != f { categoryId = f == .expense ? Category.otherExpense : Category.otherIncome }
                }
                if imported {
                    LabeledContent("Tutar", value: formatTL(entry!.amount))
                } else {
                    TextField("Tutar (₺)", text: $amount).keyboardType(.decimalPad).focused($focused)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.state.categories.filter { $0.flow == flow }) { c in
                            Button(c.name) { categoryId = c.id }
                                .buttonStyle(.plain).font(.subheadline)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(c.id == categoryId ? Theme.bg : Theme.text)
                                .background(c.id == categoryId ? Theme.tint : Theme.line, in: Capsule())
                        }
                    }
                }
                TextField("Not", text: $note)
                if imported {
                    LabeledContent("Tarih", value: date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))
                } else {
                    DatePicker("Tarih", selection: $date)
                }
            }
            .themedForm()
            .navigationTitle(entry == nil ? "Yeni kayıt" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: save).disabled(parseKurus(amount) == nil) }
            }
            .task {
                guard entry == nil else { return }
                try? await Task.sleep(for: .milliseconds(400))   // sayfa açılırken odak verilirse klavye gelmiyor
                focused = true
            }
        }
    }

    private func save() {
        guard let k = parseKurus(amount) else { return }
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        model.update { s in
            guard let e = entry else {
                s.entries.append(Entry(date: date, flow: flow, amount: k, categoryId: categoryId, note: n)); return
            }
            guard let i = s.entries.firstIndex(where: { $0.id == e.id }) else { return }
            s.entries[i].note = n
            if e.bankKey != nil {
                if s.entries[i].categoryId != categoryId { s.setCategory(entryId: e.id, categoryId: categoryId) }
            } else {
                s.entries[i].flow = flow; s.entries[i].amount = k; s.entries[i].date = date; s.entries[i].categoryId = categoryId
            }
        }
        dismiss()
    }
}
