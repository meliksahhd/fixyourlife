import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import FYLCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var naming: FYLCore.Category?   // id "" → yeni kategori
    @State private var name = ""

    var body: some View {
        Form {
            Section("Alınacaklar") {
                Toggle("Öğle hatırlatması", isOn: bind(\.settings.wishReminder))
                if model.state.settings.wishReminder {
                    DatePicker("Saat", selection: minuteBinding(bind(\.settings.wishMinute)), displayedComponents: .hourAndMinute)
                }
            }
            Section("Takvim") {
                DatePicker("Bildirim saati", selection: minuteBinding(bind(\.settings.calendarMinute)), displayedComponents: .hourAndMinute)
            }
            categories(.expense, "Gider kategorileri")
            categories(.income, "Gelir kategorileri")
            Section("Dışa aktar") {
                ShareLink(item: ExportFile(name: "hareketler.csv", data: Data(csv(model.state, calendar: .current).utf8)),
                          preview: SharePreview("hareketler.csv")) { Label("Hareketler (CSV)", systemImage: "tablecells") }
                ShareLink(item: ExportFile(name: "fixyourlife-yedek.json", data: (try? Store.encode(model.state)) ?? Data()),
                          preview: SharePreview("fixyourlife-yedek.json")) { Label("Tüm veri (JSON)", systemImage: "doc") }
            }
        }
        .themedForm()
        .navigationTitle("Ayarlar")
        .alert(Text(naming?.id == "" ? "Yeni kategori" : "Yeniden adlandır"),
               isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } }), presenting: naming) { c in
            TextField("Ad", text: $name)
            Button("Vazgeç", role: .cancel) {}
            Button("Kaydet") {
                let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !n.isEmpty else { return }
                model.update { s in
                    if c.id.isEmpty { _ = s.addCategory(name: n, flow: c.flow) } else { s.renameCategory(id: c.id, to: n) }
                }
            }
        }
    }

    private func bind<T>(_ kp: WritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(get: { model.state[keyPath: kp] }, set: { v in model.update { $0[keyPath: kp] = v } })
    }

    private func categories(_ flow: Flow, _ title: String) -> some View {
        Section(title) {
            ForEach(model.state.categories.filter { $0.flow == flow }) { c in
                Button(c.name) { name = c.name; naming = c }
                    .foregroundStyle(Theme.text)
                    .swipeActions {
                        if c.id != FYLCore.Category.otherExpense && c.id != FYLCore.Category.otherIncome {
                            Button("Sil", role: .destructive) { model.update { _ = $0.deleteCategory(id: c.id) } }
                        }
                    }
            }
            Button("+ Ekle") { name = ""; naming = FYLCore.Category(id: "", name: "", flow: flow) }
        }
    }
}

/// Paylaşım anında geçici klasöre sabit adla yazılan dışa aktarma dosyası.
struct ExportFile: Transferable {
    let name: String, data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { try $0.write() }.exportingCondition { $0.name.hasSuffix(".csv") }
        FileRepresentation(exportedContentType: .json) { try $0.write() }.exportingCondition { $0.name.hasSuffix(".json") }
    }

    func write() throws -> SentTransferredFile {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: u, options: .atomic)
        return SentTransferredFile(u)
    }
}
