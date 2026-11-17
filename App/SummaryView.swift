import SwiftUI
import FYLCore

struct SummaryView: View {
    @EnvironmentObject var model: AppModel
    @State private var adding = false
    private static let tr = Locale(identifier: "tr_TR")
    private static let hhmm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()

    var body: some View {
        let s = monthSummary(model.state.entries, now: Date(), calendar: .current)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rates
                    spending(s)
                    if !s.top.isEmpty { top(s.top) }
                    Button("+ Harcama / gelir ekle") { adding = true }.buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Özet")
            .refreshable { await model.refreshRates() }
            .toolbar { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") } }
            .sheet(isPresented: $adding) { EntryForm(entry: nil).environmentObject(model) }
        }
    }

    private var rates: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach([("USD", "Dolar"), ("EUR", "Euro"), ("GRA", "Gram altın")], id: \.0) { code, name in
                    let r = model.rates?.rates.first { $0.code == code }
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(name)
                        Text(r.map { formatRate($0.selling) } ?? "—").font(.headline.monospacedDigit()).foregroundStyle(Theme.text)
                        if let r {
                            Text(formatChange(r.changePercent)).font(.caption.monospacedDigit())
                                .foregroundStyle(r.changePercent > 0 ? Theme.up : r.changePercent < 0 ? Theme.down : Theme.secondary)
                        }
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            if let u = model.rates?.updated {
                Text("Güncelleme \(Self.hhmm.string(from: u))").font(.caption2).foregroundStyle(Theme.secondary)
                    .opacity(model.ratesFailed ? 0.5 : 1)
            }
        }
    }

    private func spending(_ s: MonthSummary) -> some View {
        var change = Text("")
        if let p = s.changePercent {
            change = p == 0 ? Text(" · aynı")
                : Text(verbatim: " · %\(abs(p)) \(p > 0 ? "fazla" : "az")").foregroundColor(p > 0 ? Theme.down : Theme.up)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(Date().formatted(.dateTime.month(.wide).locale(Self.tr))) · bugüne kadar harcadın")
                .font(.subheadline).foregroundStyle(Theme.secondary)
            Text(formatTL(s.spent)).font(.system(size: 40, weight: .semibold, design: .serif)).foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.5)
            (Text("Geçen ay aynı güne kadar \(formatTL(s.lastMonthToDate))") + change)
                .font(.footnote).foregroundStyle(Theme.secondary)
            Text("Geçen ayın tamamı \(formatTL(s.lastMonthTotal)) · Gelir bu ay \(formatTL(s.income))")
                .font(.footnote).foregroundStyle(Theme.secondary)
        }
        .card()
    }

    private func top(_ top: [CategoryTotal]) -> some View {
        let most = CGFloat(max(top[0].amount, 1))
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("En çok nereye")
            ForEach(top, id: \.categoryId) { t in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.state.category(t.categoryId)?.name ?? "Diğer")
                        Spacer()
                        Text(formatTL(t.amount)).monospacedDigit()
                    }
                    .font(.subheadline).foregroundStyle(Theme.text)
                    GeometryReader { g in
                        Capsule().fill(Theme.tint).frame(width: max(4, g.size.width * CGFloat(t.amount) / most))
                    }
                    .frame(height: 6)
                }
            }
        }
        .card()
    }
}
