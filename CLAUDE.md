# FixYourLife — proje notu

Kullanıcının kişisel iPhone uygulaması: Dan Koe'nun "How to fix your entire life in 1 day" sistemini (ve ileride eklenecek makaleleri, tek tutarlı sistem olarak sentezlenmiş hâlde) bildirim + hazır cevap butonlarıyla günlük hayata uygulatır.

- Tasarım: `docs/superpowers/specs/2026-11-03-fixyourlife-design.md` — tüm kararlar orada.
- Kaynak makaleler (tam metin): `content/sources/`
- Yığın: SwiftUI, yerel bildirimler, Codemagic → TestFlight. Kullanıcıda Mac yok (Windows), Apple Developer hesabı var.
- Dil: her şey Türkçe.

## Durum (2026-11-04)
Plan 1'in (`docs/superpowers/plans/2026-11-03-fixyourlife-plan-1-cekirdek.md`) tüm kodu `plan-1` dalında; Linux testleri + iOS simülatör derlemesi CI'da yeşil. **Sıradaki adım:** 2026-11-08 Pazar Apple/Codemagic kurulumu (`docs/kurulum.md`) → etiket → TestFlight → cihazda Task 8/9 doğrulaması ve bir gün yaşama. Ardından `plan-1` → `main` birleştirme.

## Makale ekleme akışı
Kullanıcı yeni makale linki getirdiğinde: tam metni `content/sources/` altına kaydet → sisteme ne kattığını belirle → çakışanları birleştir, çelişkileri kullanıcıya sor → `content/system.json` + `content/CHANGELOG.md` güncelle. Günlük bildirim sayısı sabit kalır; omurga Dan Koe oyun yapısı.
