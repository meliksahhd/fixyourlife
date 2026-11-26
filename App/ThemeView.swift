import SwiftUI
import FYLCore

/// Ayarlar → Tema: her renk için hazır seçenekler (ilki varsayılan) ve serbest seçim. Değişiklik anında uygulanır.
struct ThemeView: View {
    @EnvironmentObject var model: AppModel

    private static let slots: [(title: String, key: WritableKeyPath<AppTheme, Int>, options: [Int])] = [
        ("Zemin", \.bg, [0x0B0B0C, 0x0F1620, 0x0F1611, 0x1A1412, 0x1C1A24, 0xF5F2EA, 0xFFFFFF]),
        ("Kart", \.card, [0x151517, 0x1B2430, 0x18221B, 0x261D19, 0x2A2735, 0xFFFFFF, 0xECE8DF]),
        ("Yazı", \.text, [0xEDEBE6, 0xFFFFFF, 0xD9E2EC, 0xF3E9D2, 0x1A1A1A, 0x2B2622]),
        ("İkincil yazı", \.secondary, [0xA8A49D, 0x8A94A0, 0x9AA59A, 0xB8A58C, 0x6B655E, 0x777777]),
        ("Vurgu (düğme, sekme)", \.tint, [0xC9A66B, 0x6EA8FE, 0xB388FF, 0x4DD0E1, 0xF06292, 0xFFB74D]),
        ("Artış / gelir", \.up, [0x4CAF7A, 0x2ECC71, 0x26A69A, 0x7CB342, 0x1E88E5]),
        ("Düşüş / fazla harcama", \.down, [0xE5534B, 0xFF6B6B, 0xD9480F, 0xC2185B, 0xB00020]),
    ]

    var body: some View {
        let theme = model.state.settings.theme
        Form {
            ForEach(Self.slots, id: \.title) { slot in
                Section(slot.title) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(slot.options, id: \.self) { hex in
                                let on = theme[keyPath: slot.key] == hex
                                Button { set(slot.key, hex) } label: {
                                    Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                        .overlay(Circle().stroke(on ? Theme.tint : Theme.line, lineWidth: on ? 3 : 1))
                                }
                                .buttonStyle(.plain)   // Form satırında her düğme ayrı dokunulsun
                                .accessibilityLabel(String(format: "Renk %06X", hex))
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                            ColorPicker("Özel renk", selection: Binding(get: { Color(hex: theme[keyPath: slot.key]) },
                                                                        set: { set(slot.key, $0.hex) }), supportsOpacity: false)
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Theme.card)
            }
            Section {
                Button("Varsayılana dön") { model.state.settings.theme = AppTheme(); model.save() }
                    .disabled(theme == AppTheme())
            }
            .listRowBackground(Theme.card)
        }
        .themedForm()
        .navigationTitle("Tema")
    }

    /// `update` değil: renk seçici sürüklenirken her adımda bildirimler yeniden kurulmasın.
    private func set(_ key: WritableKeyPath<AppTheme, Int>, _ hex: Int) {
        if key == \AppTheme.bg { model.state.settings.theme.setBackground(hex) }
        else { model.state.settings.theme[keyPath: key] = hex }
        model.save()
    }
}
