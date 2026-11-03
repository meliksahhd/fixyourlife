# FixYourLife — proje notu

Kullanıcının kişisel iPhone uygulaması: Dan Koe'nun "How to fix your entire life in 1 day" sistemini (ve ileride eklenecek makaleleri, tek tutarlı sistem olarak sentezlenmiş hâlde) bildirim + hazır cevap butonlarıyla günlük hayata uygulatır.

- Tasarım: `docs/superpowers/specs/2026-11-03-fixyourlife-design.md` — tüm kararlar orada.
- Kaynak makaleler (tam metin): `content/sources/`
- Yığın: SwiftUI, yerel bildirimler, Codemagic → TestFlight. Kullanıcıda Mac yok (Windows), Apple Developer hesabı var.
- Dil: her şey Türkçe.

## Durum (2026-11-03)
Tasarım onaylandı. Uygulama planı yazıldı: `docs/superpowers/plans/2026-11-03-fixyourlife-plan-1-cekirdek.md` (Plan 1 = çekirdek; ayna, tırmanma, boss/yıllık, uzak içerik ve alışkanlıklar Plan 2'ye ayrıldı). **Sıradaki adım:** kullanıcı planı gözden geçirip yürütme yöntemini seçecek, ardından Task 1'den başlanacak. Public repo oluşturmadan önce kullanıcıya sorulacak.

## Makale ekleme akışı
Kullanıcı yeni makale linki getirdiğinde: tam metni `content/sources/` altına kaydet → sisteme ne kattığını belirle → çakışanları birleştir, çelişkileri kullanıcıya sor → `content/system.json` + `content/CHANGELOG.md` güncelle. Günlük bildirim sayısı sabit kalır; omurga Dan Koe oyun yapısı.
