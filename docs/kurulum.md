# Kurulum: Apple + Codemagic (tek seferlik, Pazar 8 Kasım)

Bu adımları bir kez yapacaksın. Sonra her yeni sürüm tek bir komutla telefonuna gelir. Toplam süre yaklaşık 45 dakika. Mac gerekmez, hepsi tarayıcıdan yapılır.

1. **Bundle ID kaydı.** [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Certificates, IDs & Profiles → Identifiers → **+** → App IDs → App. Description: `FixYourLife`, Bundle ID: **Explicit** `com.meliksahhd.fixyourlife`. Capabilities'e dokunma (bildirimler için ek yetki gerekmez). Continue → Register.
   - Bitti mi? Ekranda şunu görmelisin: Identifiers listesinde `com.meliksahhd.fixyourlife` satırı.

2. **Uygulama kaydı.** [App Store Connect](https://appstoreconnect.apple.com) → Uygulamalar → **+** → Yeni Uygulama. Platform: iOS, Ad: `FixYourLife` (alınmışsa `FixYourLife Kişisel`), Birincil dil: Türkçe, Bundle ID: az önce kaydettiğin, SKU: `fixyourlife`, Erişim: Tam erişim.
   - Bitti mi? Ekranda şunu görmelisin: uygulamanın sayfası açılır. Sol menüde **Uygulama Bilgileri** → **Apple Kimliği** altında 10 haneli bir sayı. **Bu sayıyı bana ilet.**

3. **API anahtarı.** App Store Connect → Kullanıcılar ve Erişim → **Entegrasyonlar** → App Store Connect API → Takım Anahtarları (Team Keys). İlk kez giriyorsan önce **Erişim İste (Request Access)** düğmesine bas ve koşulları kabul et. Sonra **+**. Ad: `codemagic`, Erişim: **App Manager**. Oluştur, sonra **API Anahtarını İndir** ile `.p8` dosyasını indir. Bu dosya yalnızca bir kez indirilebilir, kaybetme ve kimseyle paylaşma. Sayfanın üstündeki **Issuer ID** ile satırdaki **Key ID**'yi not et.
   - Bitti mi? Ekranda şunu görmelisin: listede `codemagic` anahtarı, durumu Etkin. Bilgisayarında `AuthKey_XXXX.p8` dosyası.

4. **Codemagic hesabı.** [codemagic.io](https://codemagic.io/start/) → **Sign up with GitHub** → `meliksahhd/fixyourlife` reposuna izin ver → Add application → repo'yu seç → proje türü olarak **iOS App** seç.
   - Bitti mi? Ekranda şunu görmelisin: Applications listesinde `fixyourlife`. "codemagic.yaml bulunamadı" derse sayfadaki dal seçiciden `plan-1`'i seç ve tekrar kontrol et. Bu bir hata değil, dosya henüz o dalda.

5. **Anahtarı Codemagic'e bağla.** Codemagic → sağ üstten Team/Personal settings → **Integrations** → Developer Portal → Connect (ya da Manage keys → Add key). Adı tam olarak **`fyl_asc`** olmalı. Issuer ID, Key ID ve `.p8` dosyasını gir.
   - Bitti mi? Ekranda şunu görmelisin: Developer Portal satırında yeşil tik ve `fyl_asc` anahtarı.

6. **İmzalama.** Codemagic → Team/Personal settings → **Code signing identities** → iOS certificates → **Generate certificate**. Tür: Apple Distribution, anahtar: `fyl_asc`. Codemagic sana sertifika şifresi gösterir; kaydetmen gerekmez. Sonra profili oluştur: developer.apple.com → Profiles → **+** → Distribution: **App Store Connect** → App ID: `com.meliksahhd.fixyourlife` → az önce Codemagic'in oluşturduğu Apple Distribution sertifikası → ad: `fyl_appstore` → Generate. Ardından Codemagic → **iOS provisioning profiles** → **Fetch profiles** → `fyl_appstore`'u seç → Download selected.
   - Bitti mi? Ekranda şunu görmelisin: certificates listesinde bir Apple Distribution sertifikası, profiles listesinde `com.meliksahhd.fixyourlife` için bir App Store profili.

7. **TestFlight.** iPhone'a App Store'dan **TestFlight** uygulamasını kur. App Store Connect → uygulaman → TestFlight → **İç Test / Dahili Test (Internal Testing)** yanındaki **+** → grup adı `ben` → kendi Apple hesabını test edici olarak ekle. "Otomatik dağıtım" (Automatic distribution) kutusu işaretli kalsın.
   - Bitti mi? Ekranda şunu görmelisin: `ben` grubunda kendi adın. İlk derleme gelince TestFlight uygulamasında FixYourLife görünecek.

## Sonra (ben yaparım)

Sen 2. adımdaki Apple Kimliği numarasını ilettikten sonra `codemagic.yaml` içine yazıp `build-1` etiketiyle ilk derlemeyi başlatırım. Yaklaşık 15 dakika sonra TestFlight'ta 0.1.0 sürümü görünür.

## Telefonda kontrol listesi

İlk derleme gelince bunları dene, aksayanı bana yaz:

- [ ] Uygulama açılıyor, karşılama ekranı görünüyor.
- [ ] "Bildirimlere izin ver" → izin istemi çıkıyor, "İzin Ver" diyorsun.
- [ ] "Bildirim ayarlarını aç" seni FixYourLife'ın bildirim ayarlarına götürüyor. Önizlemeleri Göster: **Kilit Açıkken** yap.
- [ ] Kurulum gününü seçip kaydediyorsun, "Hazırlan" ekranı tarihi doğru gösteriyor.
- [ ] Kurulum günü: sabah protokolünü sonuna kadar git (Geri de çalışıyor). Uygulamayı kapatıp açınca kaldığın sorudan devam ediyor.
- [ ] Gün içi sorular 11:00, 12:30, 13:30, 15:15, 16:15, 17:00, 18:30, 19:30, 21:00'de, sentez hatırlatması 22:00'de geliyor.
- [ ] Akşam sentezinde zorunlu alanlardan biri boşken "Oyunu başlat" pasif. Hepsi doluyken kaydediyorsun, oyun tahtası açılıyor.
- [ ] Tahtada Ayarlar → **Test bildirimi**. Ana ekrana dön (uygulamayı kaydırıp kapatma). Yaklaşık 1 dakika sonra bildirim geliyor, kilitliyken "Sana bir sorum var" yazıyor.
- [ ] Bildirime uzun bas, butonlar görünüyor. **"Çoğu ölüydü"** butonuna bas: uygulama açılmadan birkaç saniye içinde takip sorusu geliyor.
- [ ] Takip sorusundaki "Yazıyorum" butonunda klavye açılıyor, yazıp **Gönder** diyebiliyorsun.

## 0.2.0: Fotoğraflar

**Unsplash anahtarı (tek seferlik).** [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications) → uygulaman (`FixYourLife`) → **Keys** → **Access Key**'i kopyala. Uygulamada oyun tahtası → Ayarlar (dişli) → **Fotoğraflar** → anahtarı yapıştır → **Kaydet**. "Fotoğraflar açık" görünmeli. Anahtar yalnızca telefonun Keychain'inde durur; repoya ya da bir dosyaya yazılmaz.

- [ ] Ayarlar → Fotoğraflar: anahtar kaydedilince birkaç saniye sonra "önbellekte N fotoğraf" sayısı artıyor (ekranı kapatıp açınca güncellenir).
- [ ] **Test bildirimi**: bildirimde sağda küçük fotoğraf var; uzun basınca fotoğraf büyük açılıyor. Üstte "Kesinti · test" başlığı, altında kısa alt satır ("Canlı mıydın, ölü müydün?").
- [ ] Butonların yanında simgeler var (güneş, ay, soru işareti…).
- [ ] Takip sorusu aynı grupta, aynı başlıkla geliyor.
- [ ] Günün planlı bildirimleri Bildirim Merkezi'nde tek grupta toplanıyor; sabah bildirimi "Sabah", kesintiler "Kesinti · 2 / 6" gibi numaralı.
- [ ] Oyun tahtasının üstünde bugünün sabah fotoğrafı ve sağ altında "Foto: <ad> / Unsplash" atfı var; atfa dokununca fotoğrafçının sayfası açılıyor.
- [ ] Uçak modunda test bildirimi yine geliyor (fotoğraf önbellekten; önbellek boşsa fotoğrafsız).
- [ ] Beğenmediğin fotoğraf temasını bana yaz ("kaçış fotoğrafları fazla karanlık" gibi); sorguları içerikte değiştiririm.
