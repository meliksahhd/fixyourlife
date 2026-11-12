# FixYourLife — Görsel kimlik ve mesaja özel fotoğraflar

Tarih: 2026-11-12 · Durum: taslak, kullanıcı onayı bekliyor · Önceki belge: `2026-11-03-fixyourlife-design.md`

## 1. Amaç ve neden

Uygulama 0.1.0 telefonda çalışıyor, ama tüm ekranlar iOS'un ayar formu (`Form`) görünümünde, bildirimler de yalın metin. Kullanıcı uygulamayı her gün kullanacak. Vaktinin çoğu **bildirimlere cevap verirken** geçecek. Bu yüzden asıl vitrin bildirim. Kullanıcı tasarımları "çok metin odaklı" buldu ve görsel istedi.

İstediği şey: **o an uygulama ne söylüyorsa onu temsil eden modern bir fotoğraf** ("motto" bu demek, yazılı bir cümle değil). Fotoğrafın işi **bir şey hissettirmek**. İlerleme ya da veri göstermesi şimdilik istenmiyor. Fotoğraflar **kendiliğinden yenilenmeli**, kullanıcı elle görsel eklemek istemiyor. **Klasik tablo istemiyor.**

Maketler (yönün kaynağı): https://claude.ai/artifact/AmUQdGpuU9cW7BCFWLAop9 (4 ekran: bildirim şimdi/önerilen, uzun basınca, sabah sorusu, oyun tahtası). Fotoğraf katmanı maketlerde yok, bu belge ekliyor.

## 2. Hedefler

1. Her bildirim, mesajının temasına uygun ve daha önce gösterilmemiş bir Unsplash fotoğrafıyla gelir (iOS bildirim eki: kilit açıkken küçük önizleme, uzun basınca büyük).
2. Bildirimler başlık ve alt satır kazanır, günün bildirimleri tek grupta toplanır.
3. Uygulama ekranları maketteki görsel dile geçer: koyu, sade, serif soru, tek kırmızı vurgu. Sabah sorusu ekranı ve oyun tahtası üstte fotoğrafla açılır.
4. Simge aynı fikirde kalır, daha kalın ve küçük boyda da okunur hâle gelir.

## 3. Hedef olmayanlar (bu tur)

- Uzun basınca açılan özel pencere (Notification Content Extension). Ekstra iOS hedefi ve ikinci imza profili gerektiriyor. Fotoğraf eki işin çoğunu karşılıyor. Sonra eklenebilir.
- Özel bildirim sesi.
- Fotoğrafın üstüne yazı (kullanıcı istemedi).
- Fotoğrafla ilerleme ya da veri gösterme.
- Pinterest entegrasyonu (onay süreci, 30 günlük anahtar yenileme ve yalnızca kendi panolara erişim yüzünden elendi).
- Kullanıcının fotoğraf seçicisinden elle görsel eklemesi.

## 4. Anti-hedefler (çalışsa bile başarısızlık)

- **Bildirimin gitmemesi ya da gecikmesi.** Fotoğraf hiçbir koşulda bildirimi engellememeli. Fotoğraf yoksa bildirim fotoğrafsız gider.
- **Kurulan bildirim sırasında ağa çıkılması.** Bildirim butonuna basınca iOS'un verdiği arka plan süresi kısa. Orada indirme yapılırsa takip sorusu gelmeyebilir.
- **Alakasız ya da rahatsız edici fotoğraf** ("kaçış" sorusuna kedi fotoğrafı). Arama kelimeleri ve filtreler buna göre seçilir.
- **Unsplash anahtarının açık repoya girmesi.** Repo herkese açık (`meliksahhd/fixyourlife`).
- **Telefonda sınırsız büyüyen önbellek.**

## 5. Kısıtlar

- iOS 17+, SwiftUI, yerel bildirimler. Kullanıcıda Mac yok, derleme Codemagic'te.
- Plan 6 gün ileriye kadar en çok 60 bildirim kurar (`Planner.swift`). Ekli fotoğraflar **bildirim kurulurken diskte hazır** olmalı. iOS ek dosyasını kendi deposuna taşır, bu yüzden her bildirime ayrı bir kopya verilir.
- Unsplash demo anahtarı saatte 50 istek sınırına sahip. Fotoğraf dosyalarının (images.unsplash.com) indirilmesi bu sınıra sayılmaz, aramalar sayılır.
- Kilit ekranında önizlemeler "Kilit Açıkken" ayarında (kurulumda böyle öneriliyor). Bu yüzden kilitliyken fotoğraf **görünmez**, yalnızca "Sana bir sorum var" görünür. Bu bilinen ve kabul edilen bir durum: mahremiyet önce gelir.
- Her şey Türkçe.

## 6. Verilen kararlar

### 6.1 Fotoğraf kaynağı: Unsplash API

- Kullanıcı unsplash.com/developers adresinde ücretsiz hesap ve uygulama açar, **Access Key**'i uygulamanın Ayarlar ekranındaki bir alana kendisi yapıştırır. Anahtar cihazda saklanır (Keychain), koda ve repoya girmez.
- Anahtar girilmemişse uygulama fotoğrafsız çalışır. Bugünkü davranış bozulmaz.
- Arama: `GET /search/photos`, `orientation=portrait`, `content_filter=high`, `per_page=30`.
- Atıf: Unsplash kuralı gereği fotoğrafçı adı ("Foto: Ad Soyad / Unsplash") uygulama içinde fotoğrafın köşesinde küçük yazıyla görünür. Bildirimde atıf gerekmez, yer yok.

### 6.2 Mesaj → tema

- `content/system.json` içindeki her düğüm (node) yeni bir alan alır: `imageQueries`, 2–3 İngilizce arama ifadesi (Unsplash İngilizce aramada çok daha iyi sonuç veriyor). Örnekler:
  - `i_avoid` (neyden kaçıyorsun): "empty corridor", "closed door", "running away"
  - `i_alive` (en canlı an): "morning light run", "ocean wave", "sunlight window"
  - `i_filmed` (filme çekilse): "film camera", "cinema dark", "observer silhouette"
  - `morning` (kimlik): "mountain summit sunrise", "dawn road"
  - `synthesis` (akşam): "desk lamp night", "quiet city night"
  - `quest_check` (görev): "athlete training", "focused work desk"
- Alan içerik verisinde durur, yani makale ekleme akışıyla birlikte güncellenir. `imageQueries` olmayan düğüm fotoğrafsız gider.
- İlk sürümde tüm düğümlerin ifadelerini Claude yazar, kullanıcı fotoğraflara bakıp beğenmediğini söyler.

### 6.3 Önbellek ve zamanlama

- **Ağ yalnızca iki yerde kullanılır:** uygulama ön plana geldiğinde ve iOS arka plan yenilemesinde (`BGAppRefreshTask`, günde yaklaşık bir kez). Bildirim butonu işlenirken (`receive`) ve bildirimler kurulurken (`Notifier.apply`) **ağa hiç çıkılmaz**, yalnızca önbellekteki dosyalar kullanılır.
- Her düğüm için önbellekte birkaç kullanılmamış fotoğraf hazır tutulur. Azalınca o düğüm için yeni bir arama yapılır, gelen sonuçlardan daha önce gösterilmemiş olanlar alınır.
- Gösterilen fotoğrafların kimlikleri kalıcı olarak saklanır, aynı fotoğraf tekrar gelmez. Bir düğümün arama sonuçları tükenirse sonraki sayfaya geçilir, o da biterse en eski gösterilen fotoğraflar tekrar kullanılabilir.
- Fotoğraf 1080 px genişlikte indirilir (Unsplash URL'sindeki `w=1080` parametresi), JPEG.
- Önbellek bir üst sınırla tutulur. Kullanılmış ve artık hiçbir bekleyen bildirime bağlı olmayan dosyalar silinir.
- Bildirim kurulurken her öğeye o düğümün önbelleğinden bir fotoğraf atanır ve atama planla birlikte saklanır. Böylece uygulama içi ekran aynı bildirimin fotoğrafını gösterebilir, aynı bildirim yeniden kurulduğunda da (replan) fotoğrafı değişmez.

### 6.4 Bildirim metni

- **Başlık:** günün neresinde olunduğu. "Sabah", "Kesinti · k / n" (o günün kesinti sırası ve toplamı), "Görev", "Kapanış", "Kurulum günü". Takip soruları başlık olarak bağlı oldukları sorunun başlığını alır.
- **Alt satır:** sorunun özü, birkaç kelime. Her düğüme `system.json`'da yeni bir `gist` alanı eklenir ("Canlı mıydın, ölü müydün?" gibi). Yoksa alt satır boş kalır.
- **Gövde:** bugünkü metin, değişmez.
- **Gruplama:** `threadIdentifier` mantıksal gün olur (`plan-YYYYMMDD`), takip soruları da ait oldukları günün grubuna girer.
- **Buton simgeleri:** her butona uygun bir SF Symbol (`UNNotificationActionIcon`). Düğüm ya da buton başına `icon` alanı `system.json`'da durur, yoksa simgesiz.

### 6.5 Uygulama ekranları

Maketteki dil, dört ekranın tamamında:
- Uygulama her zaman koyu temada açılır. Zemin `#0B0B0C`, metin `#EDEBE6`, ikincil metin `#A8A49D`, kart `#151517`, tek vurgu kırmızısı `#E5534B` (simgedeki kırmızı).
- Sorular ve kimlik cümlesi Apple'ın serif yazı tipi New York ile yazılır (`.fontDesign(.serif)`). Etiketler küçük, harf aralıklı ve büyük harf. Gövde metni SF Pro.
- **Sabah sorusu:** tam ekran tek soru, açıklaması italik, üstte ilerleme çizgisi ve "1 / 14", altta tek büyük "Kâğıda yazdım" butonu. Üstte o sorunun fotoğrafı ekranın yaklaşık üçte birini kaplar, koyu zemine yumuşakça geçer. Fotoğraf için kurulum günü soruları da `imageQueries` alır.
- **Oyun tahtası:** üstte günün sabah bildiriminin fotoğrafı, üzerinde ya da altında büyük serif kimlik cümlesi. Altında boss kartı (30 günlük ilerleme çubuğu), görevler, yan yana vizyon/anti-vizyon kartları, 1 yıl hedefi, en altta düşman ve kurallar.
- **Karşılama, bekleme, kimlik, gün içi ve akşam sentezi ekranları:** aynı dile geçer (koyu, serif başlık, kart). Fotoğraf zorunlu değil.
- Görev işaretlemede hafif dokunsal geri bildirim (`.sensoryFeedback`).
- Tüm metinler Dynamic Type ile büyüyebilmeli, dokunma alanları en az 44 pt.

### 6.6 Simge

Aynı fikir (koyu zemin, açık çerçeve, ortada kırmızı kare). Çerçeve daha kalın, kompozisyon daha büyük. Maketteki "önerilen" simge buna örnek. Tek bir 1024 px PNG.

## 7. Kurucuya bırakılanlar

- Önbellekte düğüm başına kaç fotoğraf tutulacağı, üst sınır (öneri: düğüm başına 3, toplam ~150 MB'ın çok altında) ve temizleme zamanlaması.
- Saatlik 50 arama sınırına uyma yöntemi (örn. bir yenilemede en çok N arama, kalanlar sonraki açılışa).
- Unsplash "download" izleme uç noktasının çağrılıp çağrılmayacağı. Kişisel, yayımlanmayan bir uygulama için zorunlu değil, demo sınırını yer.
- Fotoğrafın ekranlarda nasıl kırpılıp karartılacağı (okunabilirlik için koyu geçiş).
- Takip sorularının başlık metni ve kesinti sıra numarasının nasıl hesaplanacağı.
- Fotoğraf atamasının hangi veri yapısında tutulacağı (`PlannedItem`'a alan eklemek ya da ayrı bir eşleme).
- Test yaklaşımı: FYLCore'a düşen saf mantık (fotoğraf seçimi, tekrar önleme, başlık/sıra hesabı) Linux testleriyle. Ağ ve iOS kısmı derleme ve cihazda deneme ile.

## 7b. Kurucu kontrolünden sonra verilen kararlar (Claude'un kararı, kullanıcı okurken kontrol etsin)

1. **Uygulama içi fotoğraf = bildirimdeki fotoğraf.** Fotoğraf ataması planlanan öğede durur (`PlannedItem`'a isteğe bağlı fotoğraf kimliği). Öğe "gönderildi" olayına dönüşürken kimlik olaya taşınır. Oyun tahtası bugünün `morning` öğesinin ya da olayının fotoğrafını gösterir. Kurulum günü soruları bildirim olmadığı için kendi atamalarını `setupNotes` içinde (`foto.<soru anahtarı>`) tutar. Atanan dosya silinmişse o düğümün önbelleğinden herhangi bir fotoğraf gösterilir.
2. **Fotoğraf yoksa** ekranlar fotoğraf alanını göstermez, düz koyu zemin kalır ve içerik yukarı kayar. Yer tutucu görsel yok. Anahtar girilmemişse Ayarlar'da "Fotoğraflar kapalı" satırı ve anahtar alanı, oyun tahtasında bir kez kapatılabilen küçük bir ipucu kartı görünür.
3. **"Gösterildi" sayılma anı:** fotoğraf bildirimin saati geçince (mevcut `harvestSent` anında) gösterilmiş sayılır. Atanmış ama saati gelmemiş fotoğraflar rezerve kalır. Yeniden planlamada aynı öğe kimliği aynı fotoğrafı korur, kimlik boşa harcanmaz.
4. **Atıf:** her fotoğrafın yanında küçük bir üstveri dosyası (fotoğrafçı adı, profil bağlantısı, Unsplash kimliği) durur. Uygulamadaki atıf yazısına dokununca fotoğrafçının Unsplash sayfası Safari'de açılır. Anahtar kaydedilirken tek bir deneme isteğiyle doğrulanır (saatlik 50'den 1'i).
5. **İçerik geçişi bu planın parçası:** `gist`, `imageQueries` ve buton `icon` alanlarını **tüm** düğümler için (kurulum soruları dahil) Claude yazar, gerçek düğüm kimliklerine ve rollerine göre. Başlık eşlemesi de mevcut rollerden çıkar: `morning` → "Sabah", kesinti rolü → "Kesinti · k / n", `quest_check` → "Görev", `synthesis` → "Kapanış", kurulum programı → "Kurulum günü", `reopen` → başlıksız. İlk derlemeden sonra kullanıcı fotoğraflara bakar, beğenmediği temalar ayarlanır.
6. **Takip soruları** bağlı oldukları sorunun başlığını ve "k / n" numarasını aynen alır. k, o gün planlanan kesintiler arasındaki sıradır (kaydırma ya da atlama numarayı değiştirmez). n, o günün kesinti sayısıdır.

## 8. Bilinen riskler

- Unsplash arama kalitesi değişken. İlk turda bazı düğümlerin ifadeleri ayarlanacak.
- iOS arka plan yenilemesinin ne zaman çalışacağı garanti değil. Uygulama birkaç gün hiç açılmazsa önbellek tükenebilir, bildirimler fotoğrafsız gider. Kabul edilebilir.
- Kullanıcı demo anahtarını çok sık yenileme yaparak tüketirse o saat fotoğraf gelmez. Bildirim etkilenmez.
- Bildirim eki dosya boyutu sınırı (resimde 10 MB) 1080 px JPEG'le sorun değil.
