import SwiftUI

/// Koyu, serif. Kırmızı = düşüş / fazla harcama, yeşil = artış / az harcama / gelir, altın = nötr vurgu.
/// Uygulama her zaman koyu temada açılır.
enum Theme {
    static let bg = Color(hex: 0x0B0B0C), text = Color(hex: 0xEDEBE6), secondary = Color(hex: 0xA8A49D)
    static let card = Color(hex: 0x151517), accent = Color(hex: 0xE5534B), line = Color(hex: 0x2A2A2D)
    static let up = Color(hex: 0x4CAF7A), down = accent, tint = Color(hex: 0xC9A66B)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
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
