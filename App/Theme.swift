import SwiftUI
import FYLCore

/// Renkler Ayarlar → Tema'dan gelir (`AppTheme`); varsayılan koyu, serif. Kırmızı = düşüş / fazla harcama,
/// yeşil = artış / az harcama / gelir, altın = nötr vurgu. Açık zemin seçilirse sistem öğeleri açık çizilir.
enum Theme {
    /// AppModel, durum her değiştiğinde günceller.
    static var current = AppTheme()
    static var bg: Color { Color(hex: current.bg) }
    static var card: Color { Color(hex: current.card) }
    static var text: Color { Color(hex: current.text) }
    static var secondary: Color { Color(hex: current.secondary) }
    static var up: Color { Color(hex: current.up) }
    static var down: Color { Color(hex: current.down) }
    static var tint: Color { Color(hex: current.tint) }
    static var line: Color { text.opacity(0.13) }
}

extension Color {
    init(hex: Int) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    /// 0xRRGGBB (ColorPicker'dan gelen geniş gamut değerleri kırpılır).
    var hex: Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return c(r) << 16 | c(g) << 8 | c(b)
    }
}

/// 11 pt, yarı kalın, geniş harf aralığı, büyük harf.
struct SectionLabel: View {
    let text: String
    var color = Theme.secondary
    init(_ text: String, color: Color = Theme.secondary) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased(with: Locale(identifier: "tr_TR"))).font(.caption2.weight(.semibold)).tracking(1.6).foregroundStyle(color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Theme.bg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.text.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func card(_ color: Color = Theme.card) -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: 18))
    }
    /// `Form` ekranları: sistem zemini yerine tema zemini.
    func themedForm() -> some View { scrollContentBackground(.hidden).background(Theme.bg) }
}
