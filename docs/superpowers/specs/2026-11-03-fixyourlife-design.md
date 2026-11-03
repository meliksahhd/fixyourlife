# FixYourLife — Tasarım Belgesi

Tarih: 2026-11-03 · Durum: **onaylandı (2026-11-03)**

## 1. Amaç ve neden

Kullanıcı, Dan Koe'nun "How to fix your entire life in 1 day" makalesindeki sistemi (ve ileride ekleyeceği başka makaleleri) okuyup unutmak değil, **günlük hayatına gerçekten uygulamak** istiyor. Bunun için yalnızca kendi iPhone'unda çalışan, gün boyu bildirimle onu bulan, bildirim üzerindeki **hazır cevap butonlarıyla** onunla "konuşan" ve cevaplara göre ilerleyen bir uygulama istiyor.

Kaynak makalenin tam metni: `content/sources/2026-01-12-dan-koe-how-to-fix-your-entire-life-in-1-day.md`.

Makalenin uygulamaya taşınan çekirdeği:
- Kimlik > eylem: sonucu üreten yaşam tarzını sonuçtan önce yaşa.
- Her davranış bir (çoğu bilinçsiz) hedefe hizmet eder; söze değil harekete bak.
- Otomatik pilotu kesmek için gün içi rastgele sorgulama.
- Anti-vizyon (kaçılan hayat) + vizyon (hedeflenen hayat) → 1 yıl hedefi → 1 ay projesi → günlük kaldıraçlar → kısıtlar.
- Hayatı oyuna çevirmek: vizyon = kazanma koşulu, anti-vizyon = risk, 1 yıl = ana görev, 1 ay = boss savaşı, günlük kaldıraçlar = görevler, kısıtlar = kurallar.
- Sibernetik döngü: hedef → eylem → konumu algıla → karşılaştır → düzelt.

## 2. Hedefler

1. Makalenin 1 günlük protokolünü uygulama içinde adım adım yaşatmak (kurulum günü).
2. Sonrasında her gün: sabah görevler, gün içi kesinti soruları, akşam kapanış — çoğu **bildirim butonlarıyla, uygulamayı açmadan**.
3. Kullanıcının **kendi cümlelerini** (anti-vizyon, vizyon, kimlik, düşman, hedefler) bildirimlerde ona geri yansıtmak.
4. Davranışı ölçmek ve haftalık/aylık olarak aynaya tutmak.
5. Yeni makaleler geldikçe içeriği **tek tutarlı sistem** olarak sentezlemek ve uygulamayı yeniden derlemeden telefona ulaştırmak.
6. Kullanıcının kendi alışkanlık/anekdotlarını ekleyip bildirim rotasyonuna katabilmesi.

## 3. Hedef olmayanlar (v1)

- Yapay zekâ / LLM ile dinamik soru üretimi (kullanıcı "şimdilik senaryolu" dedi; ileride eklenebilir).
- App Store'da yayın, başka kullanıcılar, hesap sistemi, sunucu.
- Android, iPad, Apple Watch, widget.
- Bulut senkronizasyonu / iCloud yedeği (bkz. §10 risk).
- Uygulama içinden makale/senaryo düzenleme arayüzü (senaryolar Claude ile yazılır, bkz. §7).

## 4. Anti-hedef (teknik olarak çalışsa bile başarısızlık)

Kullanıcının kendi sözüyle: **"Uygulamanın benim üzerimde hiçbir etkisi olmaması."**

Tasarım sonuçları:
- Etki **ölçülür** (§6.6), his değil sayı.
- Görmezden gelinen bildirim de veridir ve aynaya yansır.
- Alışmaya (habituation) karşı: soru cümleleri varyantlı, saatler kayar.
- Tekrarlayan başarısızlıkta uygulama **tırmanır** (§6.5), sessizce tekrarlamaz.
- Günlük bildirim sayısı makale eklendikçe **artmaz**; daha iyi sorular eskilerin yerine geçer.
- Ton: Dan Koe'nunki gibi doğrudan, hesap soran; vaaz veren, motivasyon posteri gibi değil. Asla "harika gidiyorsun!" tarzı boş övgü yok.

## 5. Kısıtlar (kullanıcının verdiği / ortamdan gelen)

- **Telefon:** iPhone. **Bilgisayar:** yalnızca Windows (Mac yok, yerelde Xcode/simülatör yok).
- **Derleme:** Codemagic (bulut macOS). **Dağıtım:** TestFlight. Kullanıcının **Apple Developer hesabı var**.
- **Dil:** Uygulama arayüzü ve tüm içerik Türkçe.
- **Kullanıcının günü:** 09:00–10:00 kalkış, 00:00–01:00 yatış.
- Kullanıcı kurulum gününde 5–10 kısa cümleyi telefona yazmayı kabul etti; geri kalan etkileşim mümkün olduğunca butonla.
- Kişisel cevaplar **yalnızca cihazda** kalır; hiçbir yere gönderilmez.
- **Kilit ekranı gizliliği (kullanıcının kararı):** Kişisel cümle içeren bildirimler kilit ekranında görünmez, Face ID ile açınca görünür. Uygulama, bildirim kategorilerine genel bir yer tutucu metin ("Sana bir sorum var") tanımlar. Kullanıcı tek seferlik kurulumda iOS Ayarlar → Bildirimler → FixYourLife → Önizlemeleri Göster: **Kilit Açıkken** ayarını seçer; uygulama ilk açılışta bunu adım adım gösterir. (Claude'un kararı: basitlik için bu ayar uygulamanın tüm bildirimlerine uygulanır.)
- Kullanıcının GitHub hesabı var; içerik reposu orada açılacak.

## 6. Ürün davranışı

### 6.1 Kurulum günü (Protokol)

İlk açılışta ve yılda bir (ya da kullanıcı istediğinde) çalışır. Makaledeki protokolün birebir uygulaması:

**Sabah — Psikolojik kazı (uygulama içinde, sırayla):**
- Uygulama makaledeki soruları tek tek gösterir. Makale cevapların kâğıda yazılmasını ve AI'a devredilmemesini söyler; uygulama da bunu söyler, her soruda "Kâğıda yazdım → devam" butonu olur. İsteğe bağlı kısa not alanı vardır.
- Soru grupları: (a) acı farkındalığı (4 soru), (b) anti-vizyon (7 soru: 5 yıl sonra Salı, 10 yıl, hayat sonu bedeli, o yolda önden giden kişi, bırakılacak kimlik, en utanç verici sebep, neyi koruyorsun), (c) vizyon MVP (3 soru: 3 yıl sonra ideal Salı, "Ben … tipte biriyim", bu hafta o kişi olsan yapacağın 1 şey).
- Bu bölümün sonunda **yazılı alan:** kimlik cümlesi ("Ben … tipte biriyim").

**Gün içi — Kesintiler (bildirim):** Makaledeki sabit saatler: 11:00, 13:30, 15:15, 17:00, 19:30, 21:00 + yürüyüş/yolculuk için 3 derin soru (makaledeki "[kimlik] olarak görülme ihtiyacını bırakırsam ne değişir?", "Canlılığı nerede güvenlikle takas ediyorum?", "Olmak istediğim kişinin yarın olabileceğim en küçük versiyonu ne?") gün içine dağıtılır. Bu günde butonlar "düşündüm / şimdi değil" + kısa sınıflama; asıl iş düşünmek.

**Akşam — Sentez (uygulama içinde, yazılı alanlar):**
- Neden takıldığım (en doğru gelen) — kısa metin
- Asıl düşman (içsel kalıp/inanç) — kısa metin
- Anti-vizyon tek cümle
- Vizyon MVP tek cümle
- 1 yıl merceği (tek somut şey)
- 1 ay merceği / projesi (boss)
- Günlük kaldıraçlar: 2–3 görev (yarın zaman bloğuna konacak)
- Kısıtlar (feda etmeyeceklerim) — 1–3 madde

Kurulum bitince "oyun tahtası" oluşur ve günlük döngü ertesi gün başlar.

### 6.2 Ana ekran: Oyun tahtası

Makalenin VII. bölümündeki 6 bileşen tek ekranda: Kazanma koşulu (vizyon), Risk (anti-vizyon), Ana görev (1 yıl), Boss (1 ay proje + kalan gün), Bugünün görevleri (tikli), Kurallar (kısıtlar). Ayrıca kimlik cümlesi ve düşman. Her alan düzenlenebilir.

Diğer ekranlar: Ayna (istatistik/geçmiş), Alışkanlık & anekdotlarım, Ayarlar (saatler, sessiz saatler, protokolü yeniden başlat).

### 6.3 Günlük döngü (varsayılanlar; ayarlardan değişir)

| Ne | Ne zaman | Etkileşim |
|---|---|---|
| Sabah | ~10:00 | Bugünün görevleri + kimlik cümlesi. Butonlar: "Bu kişiyim, başlıyorum" / "Görevleri değiştir" (uygulamayı açar) |
| Kesinti soruları | 11:00–23:00 arası günde **5–6**, rastgele saat, aralar en az ~75 dk | Soru + 2–4 cevap butonu; cevaba göre takip |
| Akşam kapanışı | ~23:30 | Her görev için Yaptım / Kısmen / Yapmadım; günü tek butonla değerlendir (en canlı / en ölü hissi vb.) |
| Sessiz saatler | 01:00–09:00 | Bildirim yok |
| Haftalık ayna | Pazar akşamı | Özet + 1–2 yansıtma sorusu |
| Aylık boss değerlendirmesi | Ayın son günü | Kazandım / Kısmen / Kaybettim → sonraki ayın projesini belirle (uygulamayı açar) |
| Yıllık | Kurulumdan 1 yıl sonra | Protokolü yeniden çalıştır |

Kesinti soru havuzu: makaledeki 6 kesinti sorusu + 3 derin soru + kullanıcının kendi cümlelerini kullanan şablon sorular (örn. "Anti-vizyonun: '{antiVision}'. Son 2 saat buna mı benzedi?", "'{identity}' olan biri şu an ne yapıyor olurdu?", "Düşmanın '{enemy}' bugün kazandı mı?") + kullanıcının eklediği alışkanlık/anekdotlar.

### 6.4 Buton → takip akışı (senaryo motoru)

Her soru bir **düğüm**dür: birkaç metin varyantı, 2–4 cevap butonu. Her buton:
- bir **etiket** kaydeder (ör. `kaciyordum`, `istedigim_hayat`, `kimlik_korumasi`, `bilinmiyor`) — metrikler bunlardan çıkar;
- isteğe bağlı bir **takip düğümüne** gider. Takip, birkaç saniye/dakika sonra yeni bildirim olarak gelir (uygulama açılmadan);
- isteğe bağlı kısa metin girişi açabilir (iOS bildirimde metin alanı destekler) — idareli kullanılmalı.

Örnek (15:15 sorusu):
- "Nefret ettiğin hayata mı, istediğin hayata mı ilerliyorsun?" → [İstediğim hayata] → kısa onay, akış biter · [Nefret ettiğime] → takip: "Şu an neyden kaçıyorsun?" → [Zor bir işten] [Yargılanmaktan] [Sıkıntıdan] [Bilmiyorum] → takip: "'{identity}' olan biri önümüzdeki 30 dakikada ne yapardı?" → [Onu yapıyorum] [Şimdi değil] · [Emin değilim] → takip: "Son 2 saat filmlense izleyen ne istediğini düşünürdü?" …

Takip zinciri derinliği en fazla 3. Zincir sırasında yeni kesinti sorusu araya girmez.

### 6.5 Tırmanma kuralları (anti-hedefe karşı)

- Aynı görev **3 gün üst üste** "Yapmadım" → müdahale: "Bu görev 3 gündür yapılmıyor. Ya görev yanlış, ya kendini koruyorsun. Hangisi?" → [Görev yanlış → küçült/değiştir (uygulamayı açar)] [Kendimi koruyorum → "Neyi?" takip] [Bu sefer yapacağım].
- Bir haftada kesinti sorularının **≥%50'si cevapsız** → haftalık aynada açıkça söylenir ve ertesi hafta ilk soru bununla ilgili olur.
- Belirli bir etiket (ör. `kaciyordum`) haftalık cevapların çoğunluğuysa → haftalık ayna bu örüntüyü saat dilimiyle birlikte gösterir ve düşmanla ilişkilendirir.
- Boss "Kaybettim" ile biterse → değerlendirme akışı "neden" sorar ve projeyi küçültmeyi önerir (sibernetik döngü: düzelt, bırakma).

### 6.6 Ölçüm / Ayna

Kaydedilenler: her bildirimin gönderilme zamanı, cevap (etiket) ya da cevapsızlık, cevap süresi, görev kapanışları, boss sonuçları, günlük değerlendirme.
Ayna ekranı ve haftalık özet en az şunları gösterir: görev tamamlama oranı (haftalık trend), cevap oranı, etiket dağılımı (ve gün içi saat dağılımı), en sık "yapılmayan" görev, boss geçmişi. Amaç: bir ay sonra "işe yarıyor mu?" sorusuna sayıyla cevap.

### 6.7 Kullanıcının eklediği alışkanlık ve anekdotlar

Uygulama içinde basit ekleme: metin + tür (alışkanlık / anekdot / hatırlatma) + isteğe bağlı sıklık. Alışkanlıklar akşam kapanışına görev gibi eklenebilir; anekdotlar kesinti havuzuna hatırlatma olarak girer. Günlük toplam bildirim tavanını aşmaz (havuzda yer değiştirir).

## 7. İçerik sistemi ve makale sentezi

**Karar (kullanıcının):** Makaleler ayrı paketler değil, **tek tutarlı sistem** olarak sentezlenir. Kullanıcı sık sık yeni makale ekleyecek.

**Karar (benim önerim, kullanıcı itiraz etmedi):**
- Tüm senaryo içeriği uygulama kodundan ayrı, tek bir sürümlü içerik dosyasında durur (ör. `content/system.json`): düğümler, varyantlar, butonlar, etiketler, akışlar, günlük havuz, tırmanma metinleri, protokol soruları.
- Dosya kullanıcının GitHub'ındaki bir repoda barınır; uygulama açılışta (ve arka plan fırsatı olduğunda) uzak sürümü kontrol eder, şemayı doğrular, geçerliyse kullanır; değilse son geçerli sürümde kalır. Uygulama paketinde de bir kopya gömülü gelir (ilk açılış/çevrimdışı).
- İçerik dosyası **kişisel veri içermez** (kişisel cümleler şablon değişkenleriyle eklenir: `{identity}`, `{antiVision}`, `{vision}`, `{enemy}`, `{yearGoal}`, `{monthProject}`, `{todayQuests}`, `{constraints}`).

**Sentez iş akışı:** Kullanıcı makale linkini Claude'a getirir → Claude tam metni `content/sources/` altına kaydeder → mevcut sisteme ne kattığını belirler (yeni ritüel, daha iyi soru, yeni ölçüm boyutu, yeni kısıt…) → çakışanları birleştirir, **çelişkileri kullanıcıya sorar** → `system.json`'u günceller, `content/CHANGELOG.md`'ye "neyi ekledim / çıkardım / neden" yazar → push. Kural: günlük bildirim sayısı sabit; omurga Dan Koe'nun oyun yapısı.

## 8. Teknik kararlar (verilmiş)

- **SwiftUI**, yerel iOS uygulaması (Claude'un önerisi, kullanıcı itiraz etmedi).
- **Bildirimler yerel** (UNUserNotificationCenter); sunucu yok, internetsiz çalışır. Butonlar bildirim kategorisi aksiyonları ile.
- **Codemagic** ile derleme → **TestFlight** ile kurulum. Mac olmadığı için Xcode proje dosyası elle değil, bir proje üreticiyle (ör. XcodeGen) bulutta üretilir.
- İçerik GitHub'da (bkz. §7).

## 9. Kurucuya bırakılanlar

- Minimum iOS sürümü (kullanıcının iOS sürümü bilinmiyor; makul bir güncel sürüm seç).
- Yerel kalıcılık yöntemi (SwiftData / Codable dosya vb.).
- `system.json` şemasının ayrıntısı, doğrulama yöntemi.
- iOS'un bekleyen yerel bildirim sınırı (64) ile planlama: kaç günlük pencere zamanlanacağı, uygulama uzun süre açılmazsa pencere bitmeden "beni aç" hatırlatması gibi çözümler.
- Bildirim aksiyonlarının arka planda işlenip takip bildirimi zamanlaması.
- Kesinti saatlerinin rastgeleleştirme algoritması (kısıtlar: pencere, en az aralık, takip zinciri sırasında boşluk).
- Görsel tasarım (sade, karanlık mod uyumlu, okunaklı; oyun metaforu abartılmadan).
- Codemagic iş akışı, imzalama kurulumu ve kullanıcının yapması gereken tek seferlik adımların (Bundle ID, App Store Connect API anahtarı, GitHub reposu) adım adım rehberi.
- Senaryo metinlerinin Türkçe yazımı — makaleye sadık, Dan Koe tonunda; her kesinti sorusu için en az 3 varyant.

## 9b. Kurucu kontrolünden sonra verilen kararlar (Claude'un kararı — kullanıcı okurken kontrol etsin)

1. **Takip bildirimleri:** Bildirim aksiyonu arka planda işlenir ve takip bildirimi o an zamanlanır (en iyi çaba). Her dal önceden zamanlanmaz. iOS arka plan süresini vermezse takip, uygulama bir sonraki açıldığında gösterilir. Kabul edilen bir sınır.
2. **"Cevapsız" tanımı:** Bir sonraki planlı bildirim gelene kadar (ya da en geç 2 saat içinde) dokunulmayan soru cevapsız sayılır. Bildirimin kaydırılıp kapatılması ayrıca izlenmez.
3. **Kurulum günü zamanlaması:** Protokol günü önceden planlanır. Uygulama "yarın sabah başla" der ve kullanıcı günü seçer. Kurulum gününde kesintiler makaledeki **sabit saatlerde** gelir; rastgele saatler yalnızca günlük döngüde kullanılır. Gün geç başlarsa geçmiş saatler atlanır. 3 derin soru 12:00–20:00 arasına sabit dağıtılır; konum veya hareket algılaması yok.
4. **Uzak içerik:** İçerik reposu **public** olur, çünkü içinde kişisel veri yok ve token gerekmez. Claude, değişiklik notunu kullanıcıyla sohbette paylaşıp onay aldıktan sonra push eder. Uygulama, şema doğrulamasından geçen yeni sürümü otomatik uygular. Ayarlarda içerik sürümü görünür ve "önceki sürüme dön" seçeneği bulunur.
5. **Boss süresi:** Takvim ayına değil, başlangıçtan itibaren **30 güne** bağlıdır. Haftalık ayna da kurulum gününe göre değil Pazar akşamına bağlı kalır. Yıllık değerlendirme kurulumdan 365 gün sonradır.
6. **Kurulumdaki yazılı alanlar:** Zorunlu olanlar kimlik, anti-vizyon, vizyon, düşman, 1 yıl, 1 ay projesi ve en az 1 görev. "Neden takıldım", kısıtlar ve notlar isteğe bağlı. Boş kalan bir alanı kullanan şablon soru havuzdan çıkarılır, onun yerine varsayılan metin kullanılmaz.

## 10. Bilinen riskler

- **Veri kaybı:** iCloud yedeği v1'de yok; uygulama silinirse cevaplar gider. TestFlight güncellemeleri veriyi korur. Basit bir "dışa aktar" (JSON/paylaş) eklenmesi düşünülebilir.
- **Test döngüsü yavaş:** Windows'ta simülatör yok; her deneme Codemagic → TestFlight (~15–30 dk). Mantık testleri bulutta çalıştırılmalı.
- **TestFlight sürüm ömrü 90 gün:** en geç 90 günde bir yeni derleme gerekir.
- **Bildirim yorgunluğu:** tavan ve varyantlarla yönetiliyor; ilk 2 haftanın verisine bakıp ayarlanmalı.
