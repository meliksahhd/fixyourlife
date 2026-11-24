# FixYourLife — proje notu

Kullanıcının kişisel iPhone uygulaması: para (Ziraat Excel içe aktarma, kategoriler), kurlar (Truncgil), istek listesi (öğlen hatırlatması) ve takvim (gruplanmış hatırlatmalar). Sürüm 0.3.0; bundle id, ASC uygulaması ve Codemagic aynı.

- Tasarım: `docs/superpowers/specs/2026-11-13-para-liste-takvim-design.md`
- Plan: `docs/superpowers/plans/2026-11-14-para-liste-takvim.md`
- Yığın: SwiftUI, yerel bildirimler, Codemagic → TestFlight. Mac yok (Windows), yerelde Swift yok; doğrulama GitHub Actions ile.
- Gizlilik: gerçek banka dışa aktarımları (`*.xlsx`, `*.pdf`) repoya asla girmez; repo herkese açık.
- Dil: her şey Türkçe.
- Veri uyumluluğu: `AppState`/`Settings`/modellere zorunlu (optional olmayan) alan eklerken `decodeIfPresent`'li `init(from:)` yaz. Sentezlenen `Codable` eksik anahtarda hata verir → `Store.load` eski `state.json`'u bozuk sayıp kenara alır, uygulama boş açılır.

## Durum (2026-11-17)
Planın 9 görevinin kodu `plan-2-gorsel` dalında; `test` + `ios-build` yeşil. **Sıradaki adım:** `build-3` etiketi → TestFlight 0.3.0 → cihaz kontrolü (`docs/kurulum.md`, plan Görev 9 Adım 3) → `main`'e birleştirme.
