import SwiftUI
import FYLCore

struct WishesView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: Wish?
    @State private var adding = false
    @State private var buying: Wish?

    var body: some View {
        let pending = model.state.wishes.filter { $0.boughtAt == nil }
        let bought = model.state.wishes.filter { $0.boughtAt != nil }.sorted { $0.boughtAt! > $1.boughtAt! }
        let total = pendingTotal(model.state.wishes)
        NavigationStack {
            List {
                if total > 0 {
                    Text("Bekleyen ≈ \(formatTL(total))").font(.headline.monospacedDigit()).foregroundStyle(Theme.text)
                        .listRowBackground(Theme.card)
                }
                ForEach(pending) { w in
                    HStack {
                        Button { editing = w } label: {
                            HStack {
                                Text(w.name).foregroundStyle(Theme.text)
                                Spacer()
                                if let e = w.estimate { Text(formatTL(e)).monospacedDigit().foregroundStyle(Theme.secondary) }
                            }
                            .contentShape(Rectangle())
                        }
                        Button("Aldım") { buying = w }.buttonStyle(.bordered)
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(Theme.card)
                    .swipeActions {
                        Button("Sil", role: .destructive) { model.update { $0.wishes.removeAll { $0.id == w.id } } }
                    }
                }
                if !bought.isEmpty {
                    DisclosureGroup("Alındı") {
                        ForEach(bought) { w in
                            HStack {
                                Text(w.name).foregroundStyle(Theme.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(w.paid.map(formatTL) ?? "—").monospacedDigit().foregroundStyle(Theme.text)
                                    Text(w.boughtAt!.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))
                                        .font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .themedForm()
            .navigationTitle("Alınacaklar")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { WishForm(wish: nil).environmentObject(model) }
            .sheet(item: $editing) { WishForm(wish: $0).environmentObject(model) }
            .sheet(item: $buying) { BuySheet(wish: $0).environmentObject(model) }
        }
    }
}

struct WishForm: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let wish: Wish?
    @State private var name: String
    @State private var estimate: String

    init(wish: Wish?) {
        self.wish = wish
        _name = State(initialValue: wish?.name ?? "")
        _estimate = State(initialValue: wish?.estimate.map(amountText) ?? "")
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var noEstimate: Bool { estimate.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Ad", text: $name)
                TextField("Tahmini fiyat (₺, isteğe bağlı)", text: $estimate).keyboardType(.decimalPad)
            }
            .themedForm()
            .navigationTitle(wish == nil ? "Yeni madde" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).disabled(trimmed.isEmpty || (!noEstimate && parseKurus(estimate) == nil))
                }
            }
        }
    }

    private func save() {
        let n = trimmed, k = parseKurus(estimate)
        model.update { s in
            if let i = s.wishes.firstIndex(where: { $0.id == wish?.id }) {
                s.wishes[i].name = n; s.wishes[i].estimate = k
            } else {
                s.wishes.append(Wish(name: n, estimate: k))
            }
        }
        dismiss()
    }
}

/// "Aldım": tutar girilirse seçilen kategoride gider kaydı oluşur, boşsa yalnızca "Alındı"ya geçer.
struct BuySheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let wish: Wish
    @State private var amount: String
    @State private var categoryId = FYLCore.Category.otherExpense

    init(wish: Wish) {
        self.wish = wish
        _amount = State(initialValue: wish.estimate.map(amountText) ?? "")
    }

    private var blank: Bool { amount.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ödenen tutar (₺)", text: $amount).keyboardType(.decimalPad)
                    CategoryChips(categories: model.state.categories.filter { $0.flow == .expense }, selection: $categoryId)
                } footer: {
                    Text("Boş bırakırsan harcama kaydı oluşmaz.")
                }
            }
            .themedForm()
            .navigationTitle(wish.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).disabled(!blank && parseKurus(amount) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let k = parseKurus(amount), c = categoryId
        model.update { $0.buy(wish.id, paid: k, categoryId: c, at: Date()) }
        dismiss()
    }
}
