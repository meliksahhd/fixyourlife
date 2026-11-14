# Uygulama dönüşümü: para, kurlar, alınacaklar, takvim

Tarih: 2026-11-13 · Durum: taslak, kullanıcı onayı bekliyor · Önceki belgeler: `2026-11-03-fixyourlife-design.md`, `2026-11-12-gorsel-kimlik-design.md` (ikisi de bu belgeyle **geçersiz**)

## 1. Amaç ve neden

Kullanıcı Dan Koe yansıtma sistemini (bildirimle gelen sorular, kurulum günü, oyun tahtası) bırakıyor: "sorulan sorular üzerine düşünüp cevaplanması gereken şeyler, ben böyle bir şey istemiyorum". Aynı uygulama (aynı App Store Connect kaydı, TestFlight, Codemagic hattı) dört işe dönüşüyor:

1. **Para:** harcama ve gelirlerini kaydetmek. Asıl soru "geçen ay ne harcamışım, bu ay şimdiye kadar ne harcamışım, en çok nereye harcamışım".
2. **Kurlar:** yatırım için anlık fiyatları görmek. Sadece fiyat. Portföy yok.
3. **Alınacaklar:** büyük, arada bir alınan ihtiyaçlar (örnek: bilgisayar çantası). Asıl sorun **unutmak**: "hâlâ almadım, unutuyorum ve gidiyor".
4. **Takvim:** yakınlarının doğum günleri, sınav tarihleri, görevler, özel günler. Gün gelince ya da yaklaşınca bildirim.

Kullanıcı genelde **Ziraat Bankası banka kartıyla** ödüyor. Gelir de aynı hesaba geliyor.

## 2. Hedefler

1. Uygulama açılınca ilk saniyede şunlar görünür: anlık kurlar, bu ayki harcama, geçen ayla adil karşılaştırma, en çok harcanan kategoriler.
2. Bir harcama ya da gelir birkaç saniyede elle eklenir.
3. Alınacaklar listesinde bekleyen bir şey varsa her gün öğlen hatırlatılır. Alınan şey tek dokunuşla harcamaya dönüşür.
4. Takvimdeki her olay için zamanında bildirim gelir. Hiçbiri kaçmaz.
5. Veriler telefondan dışa aktarılabilir. Uygulama silinse bile kullanıcı verisini kurtarabilir.

## 3. Hedef olmayanlar (bu sürüm)

- **Ziraat ekstresinden içe aktarma.** Araştırmaya göre bireysel müşteriye Excel/CSV verildiği doğrulanamadı, muhtemelen yalnızca PDF var. Kullanıcı gerçek bir dosya getirince ayrı bir iş olarak ele alınacak. Elle giriş tek başına yeterli olmalı.
- Bütçe limiti, birikim hedefi, banka bağlantısı.
- Portföy (elindeki altını ve dövizi girip toplam değerini görme). Kullanıcı açıkça "sadece anlık fiyatları göreyim yeter" dedi.
- Market alışverişi listesi. Liste yalnızca büyük ihtiyaçlar için.
- Rehberden doğum günü aktarma. *(Benim kararım: birkaç yakın için elle eklemek hızlı. Rehber izni ve eşleştirme kodu şimdilik gereksiz.)*
- Ay görünümlü takvim ızgarası. Liste yeterli.
- iCloud eşitleme, birden fazla cihaz, widget, Apple Watch.
- Fiş fotoğrafı.
- Birden fazla para birimi. Her tutar TL.

## 4. Anti-hedefler (çalışsa bile başarısızlık)

- **Veri kaybı.** Okunamayan durum dosyasının üzerine boş durum yazılmamalı. Mevcut `Store.load` tam olarak bunu önlüyor (okunamıyorsa `nil` döner, kayıt yapılmaz). Bu davranış korunmalı.
- **Kaçan hatırlatma.** Bir doğum gününün ya da sınavın bildirimi, 64 bildirim sınırı ya da uygulamanın uzun süre açılmaması yüzünden düşmemeli.
- **Bildirim yağmuru.** Aynı gün birden fazla olay tek bildirimde toplanır. Liste hatırlatması günde en fazla bir kez gelir. Liste boşsa hiç gelmez.
- **Harcama eklemenin zahmetli olması.** Ekleme 3 alanı geçerse kullanıcı girmeyi bırakır ve ana ekrandaki rakamlar anlamsızlaşır.
- **Kur yokken boş ekran ya da hata.** İnternet yoksa son alınan değer, saatiyle birlikte gösterilir.

## 5. Kısıtlar

- iOS 17+, SwiftUI, yerel bildirimler, sunucu yok. Kullanıcıda Mac yok. Derleme ve dağıtım Codemagic → TestFlight (`codemagic.yaml`, `build-*` etiketiyle tetiklenir, aylık 500 dakikalık ücretsiz kota).
- Bundle ID `com.meliksahhd.fixyourlife` ve ASC uygulaması (Apple ID 6833892471) **değişmez**. İmzalama Ballmark ASC anahtarını paylaşıyor.
- Saf mantık `FYLCore` paketinde kalır ve Linux CI'da test edilir (`.github/workflows/test.yml`). iOS'a özgü kod `App/` altında olur ve `ios-build.yml` ile derlenir.
- Arayüz dili tamamen Türkçe. Para biçimi `tr_TR` (14.820 ₺, 50,36).
- iOS, bir uygulamanın aynı anda en fazla 64 bekleyen bildirim kurmasına izin verir.

## 6. Kararlar

### 6.1 Ekranlar ve gezinme

Alt sekme çubuğunda dört sekme: **Özet · Hareketler · Alınacaklar · Takvim**. Ayarlar Özet'in sağ üstündeki dişli simgesinden açılır.

**Özet** (kullanıcı tarayıcıdaki iki taslaktan A'yı seçti):
1. En üstte üç kur kartı yan yana: **Dolar, Euro, Gram altın**. Her kartta satış fiyatı ve günlük yüzde değişim yer alır (artış yeşil, düşüş kırmızı). Kartların altında küçük harflerle "Güncelleme 17:59" yazar. Aşağı çekince kurlar yenilenir.
2. Harcama kartı:
   - Büyük rakam: "Kasım · bugüne kadar harcadın **14.820 ₺**".
   - "Geçen ay aynı güne kadar 12.400 ₺ · %20 fazla". Fark harcama artışıysa kırmızı, azalışsa yeşil gösterilir.
   - "Geçen ayın tamamı 27.900 ₺ · Gelir bu ay 32.000 ₺".
3. "En çok nereye" kartı: bu ayın gider kategorileri tutara göre azalan sırada, her biri yatay çubukla. Hepsi gösterilir, kategori sayısı zaten az.
4. Tam genişlikte **"+ Harcama / gelir ekle"** düğmesi.

**"Geçen ay aynı güne kadar"** tanımı: geçen ayın 1'inden, bugünün gün numarasına kadar olan giderlerin toplamı (gün dahil). Geçen ay daha kısaysa ayın son gününde kesilir (31 Mart → 28/29 Şubat). Yüzde, geçen ayın aynı güne kadarki tutarı 0 ise gösterilmez.

**Hareketler:** tüm kayıtlar tarih sırasıyla (yeniden eskiye), aylara göre gruplanmış. Satırda kategori, not, tutar görünür. Gelirler yeşil ve "+" işaretli olur. Satıra dokununca düzenleme açılır. Sola kaydırınca silinir.

**Ekleme sayfası** (alttan açılan sayfa):
- Gider/Gelir seçici (varsayılan Gider)
- Tutar (sayı klavyesi, otomatik odak)
- Kategori (yatay çipler)
- Not (isteğe bağlı)
- Tarih (varsayılan şimdi, değiştirilebilir)

Kaydet ile kapanır.

**Kategoriler** *(benim kararım, Ayarlar'dan eklenir, silinir, yeniden adlandırılır)*:
- Gider: Market, Yemek / kafe, Ulaşım, Fatura, Kira, Giyim, Eğlence, Sağlık, Eğitim, Diğer
- Gelir: Maaş, Ek gelir, Diğer

Kullanımda olan bir kategori silinirse kayıtlar "Diğer"e taşınır. Kayıtlar kategoriye ad ile değil **sabit kimlik** ile bağlanır. Yeniden adlandırma geçmiş kayıtlara da yansır. "Diğer" silinemez.

### 6.2 Kurlar

- Kaynak: `https://finans.truncgil.com/v4/today.json`, anahtar gerekmiyor. Kullanılan anahtarlar `USD`, `EUR`, `GRA` (gram altın). Gösterilen alanlar `Selling` ve `Change`. Kök alan `Update_Date` güncelleme zamanını verir.
- Sayılar Türkçe biçimli metin olarak gelebilir ("50,3635"). Ayrıştırıcı bunu ele almalı ve testle güvenceye alınmalı. Gerçek yanıt yapıcı tarafından bir kez indirilip test fikstürü yapılır. `Change` alanının yüzde mi yoksa tutar mı olduğu bu fikstürden doğrulanır.
- Kurlar Özet açıldığında, aşağı çekildiğinde ve uygulama öne geldiğinde çekilir. Arka planda çekilmez. Son başarılı yanıt diske kaydedilir. Hata olursa son değer gösterilir ve güncelleme zamanı soluk görünür.
- *Benim kararım:* bu sürümde yedek kaynak yok. Truncgil resmi bir kurum değil. Çökerse TCMB `today.xml` (USD/EUR, günde bir kez, altın yok) yedek olarak eklenir. Kodda bunun yeri `ponytail:` yorumuyla işaretlenir.

### 6.3 Alınacaklar

- Satır: ad ve isteğe bağlı tahmini fiyat. Listenin üstünde, fiyatı girilmiş bekleyenlerin toplamı yazar ("Bekleyen ≈ 4.500 ₺").
- **"Aldım":** ödenen tutar sorulur (tahmini fiyat önceden doldurulmuş, boş da bırakılabilir). Tutar girilirse "Diğer" kategorisinde bir gider kaydı oluşur, not alanına ürünün adı yazılır. Kategori sayfada değiştirilebilir. Ürün "Alındı" bölümüne geçer, ödenen tutar ve tarih yanında görünür. Alındı bölümü varsayılan olarak kapalıdır.
- Bekleyenlere dokununca düzenleme açılır, kaydırınca silinir.
- **Öğle hatırlatması:** her gün 12:30'da (Ayarlar'dan değiştirilebilir) bir bildirim gelir: başlık "Alınacaklar", gövde "Bugün alabilirsin: bilgisayar çantası, …" (en çok 3 ad ve "+N"). Liste boşsa bildirim kurulmaz. Uygulama: tekrarlayan tek bir `UNCalendarNotificationTrigger` (saat+dakika). Liste her değiştiğinde gövdesi yenilenerek yeniden kurulur. Liste yalnızca uygulamanın içinden değiştiği için gövde hep günceldir.
- Bildirime dokununca Alınacaklar sekmesi açılır.

### 6.4 Takvim

Olay alanları: ad, tür, tarih (sınav ve görev için isteğe bağlı saat), hatırlatma günleri, isteğe bağlı "hediye al" anahtarı (yalnızca doğum günü ve özel günde).

| Tür | Tekrar | Varsayılan hatırlatmalar |
|---|---|---|
| Doğum günü / özel gün | Her yıl | 3 gün önce + o gün |
| Sınav / görev | Bir kez | 7 gün önce + 1 gün önce + o gün |
| Diğer | Bir kez ya da her yıl (seçilir) | o gün |

- Hatırlatma günleri her olayda düzenlenebilir: önceden tanımlı seçenekler arasından çoklu seçim (o gün, 1, 2, 3, 7, 14, 30 gün önce).
- Bildirim saati: "o gün" ve "X gün önce" bildirimleri **09:00**'da gelir (Ayarlar'dan değiştirilebilir) *(benim kararım)*. Sınavın saati belliyse, "o gün" bildirimi yine 09:00'dadır ve gövdesinde sınav saati yazar.
- **Gruplama:** aynı ana düşen tüm hatırlatmalar tek bildirimde birleşir. Örnek: "Bugün: Annemin doğum günü 🎂 · 3 gün sonra: Matematik sınavı".
- Liste görünümü: gelecekteki olaylar en yakından uzağa sıralanır, her satırda "bugün / yarın / 3 gün kaldı" sayacı olur. Geçmiş bir kerelik olaylar alttaki "Geçmiş" bölümüne düşer.
- 29 Şubat doğum günü artık olmayan yıllarda 28 Şubat'ta kutlanır.
- **Hediye al:** doğum günü 3 gün içine girdiğinde Alınacaklar'a "🎁 <ad> için hediye" maddesi eklenir. Bu yalnızca uygulama çalışınca yapılabildiği için, uygulama her öne geldiğinde ve arka planda yenilendiğinde kontrol edilir. Her olay-yıl için en fazla bir kez eklenir. Kullanıcı maddeyi silerse o yıl yeniden eklenmez. 3 gün önceki bildirimin gövdesinde "Hediye almayı unutma" yazar. "Listene eklendi" denmez, çünkü bildirim geldiğinde uygulama henüz açılmamış olabilir.

**64 bildirim sınırı:** liste hatırlatması 1 yer tutar. Kalan 63'ten 60'ı, şu andan itibaren en yakın gruplanmış takvim bildirimlerine ayrılır. Uygulama öne geldiğinde ve her veri değişikliğinde bütün takvim bildirimleri silinip yeniden kurulur (mevcut `Notifier.apply` düzeni). Uygulama uzun süre açılmazsa: 60 grup, sıradan bir kullanıcı için aylar eder. Ayrıca mevcut arka plan yenileme (`BGAppRefreshTask`) yeniden planlama için kullanılır.

### 6.5 Ayarlar

- Liste hatırlatma saati (varsayılan 12:30) ve aç/kapat.
- Takvim bildirim saati (varsayılan 09:00).
- Kategoriler (gider ve gelir, ekle/sil/yeniden adlandır).
- **Dışa aktar:** tüm hareketler CSV olarak (`tarih;tür;kategori;tutar;not`, noktalı virgül ayırıcı ve virgüllü ondalık, Türkçe Excel doğrudan açsın diye), ayrıca tüm durum ham JSON olarak. Paylaşım sayfasıyla (`ShareLink`) Dosyalar'a ya da başka bir yere kaydedilir.

### 6.6 Veri

- Durum tek bir JSON dosyasında (`Application Support/state.json`). Mevcut `Store` deseni korunur: okunamıyorsa `nil`, bozuksa kenara al, atomik yazma.
- Tutarlar **kuruş cinsinden `Int`** olarak saklanır. Kayan nokta kullanılmaz.
- Yıllık boyut tahmini: günde 10 kayıt ≈ 1 MB/yıl. Arşivleme ya da budama gerekmez.
- Eski FixYourLife durumu (profil, olaylar, kurulum) taşınmaz. Kullanıcı yalnızca bir gün kullandı. Yeni sürüm eski `state.json` dosyasını okuyamazsa onu kenara alıp temiz başlar *(benim kararım)*.

### 6.7 Kaldırılanlar

Yansıtma sistemine ait her şey silinir:
- `content/` (`system.json`, `sources/`, `CHANGELOG.md`)
- `FYLCore` içindeki `Content`, `Engine`, `Planner`, `Photos`, `Random` ve testleri
- `App/` içindeki `BoardView`, `SetupView`, `PhotoHeader`, `PhotoCache`, `Unsplash`, `Keychain`
- Unsplash anahtarı ve fotoğraf arka plan görevi

Bunlar git geçmişinde kalır. `Theme.swift` (koyu tema, kart stili) korunur ve yeni ekranlarda kullanılır. Kırmızı vurgu rengi artık "düşüş / fazla harcama" anlamı taşır. Nötr vurgu için yapıcı bir renk seçer. `CLAUDE.md` yeni amaca göre yeniden yazılır, "makale ekleme akışı" kaldırılır.

## 7. Yapıcıya bırakılanlar

- `FYLCore` içindeki tip ve dosya düzeni, SwiftUI görünüm ayrıntıları, animasyonlar.
- Test kapsamı. En azından şunlar teste bağlanmalı:
  - aylık toplamlar ve "aynı güne kadar" kesimi (31 → 28 dahil)
  - kategori sıralaması
  - yıllık ve bir kerelik olay tekrarları (29 Şubat dahil)
  - hatırlatma tarihlerinin üretimi, gruplanması ve 60 sınırı
  - Truncgil yanıtının ayrıştırılması
  - hediye maddesinin olay-yıl başına bir kez eklenmesi
  - CSV biçimi
- Sürüm numarası (öneri: 0.3.0) ve TestFlight etiketlemesi.
