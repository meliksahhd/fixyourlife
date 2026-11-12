# Görsel kimlik ve mesaja özel fotoğraflar — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Her bildirime mesajının temasına uygun bir Unsplash fotoğrafı, başlık ve alt satır eklemek. Uygulama ekranlarını maketteki koyu, serif dile geçirmek.

**Architecture:** Saf mantık FYLCore'da kalır ve Linux'ta test edilir: içerik alanları, bildirim başlığı, fotoğraf ataması, tekrar önleme, yenileme önceliği. Ağ, önbellek, Keychain, bildirim eki ve arayüz `App/` altında. Ağa yalnızca ön plan ve arka plan yenilemesinde çıkılır. Bildirim kurulumu ve buton işleme yalnızca diskteki önbelleği kullanır.

**Tech Stack:** Swift 6.1, SwiftUI (iOS 17), UserNotifications, BackgroundTasks, Security (Keychain), URLSession, Unsplash API, XcodeGen (`project.yml`), Codemagic.

**Spec:** `docs/superpowers/specs/2026-11-12-gorsel-kimlik-design.md` (özellikle §6 ve §7b). Maketler: https://claude.ai/artifact/AmUQdGpuU9cW7BCFWLAop9

## Global Constraints

- Dal: `plan-1`'den açılan `plan-2-gorsel`. Bilgisayarda Swift yok. Testler push sonrası GitHub Actions `test` (swift:6.1, `swift test`) ve `ios-build` iş akışlarında koşar: `gh run list --branch plan-2-gorsel --limit 2` → ikisi de `completed success`.
- iOS dağıtım hedefi 17.0 kalır. Yeni üçüncü taraf bağımlılık yok.
- Tüm kullanıcıya görünen metin Türkçe. `imageQueries` İngilizce.
- Unsplash anahtarı koda, repoya, `state.json`'a girmez. Yalnızca Keychain'de durur (repo herkese açık).
- Unsplash arama: `GET https://api.unsplash.com/search/photos?query=…&page=…&per_page=30&orientation=portrait&content_filter=high`, başlık `Authorization: Client-ID <key>`. Fotoğraf `urls.raw` + `&w=1080&fm=jpg&q=80` ile indirilir.
- Renkler: zemin `#0B0B0C`, metin `#EDEBE6`, ikincil `#A8A49D`, kart `#151517`, vurgu `#E5534B`. Uygulama her zaman koyu temada açılır.
- Başlıklar: `morning` → "Sabah", kesinti → "Kesinti · k / n", `quest_check` → "Görev", `synthesis` → "Kapanış", kurulum programındaki diğerleri → "Kurulum günü", `reopen` → başlık yok.
- Fotoğraf yoksa bildirim fotoğrafsız gider. Bildirim asla fotoğraf yüzünden düşmez ya da gecikmez.
- `state.json` geriye uyumlu: tüm yeni alanlar isteğe bağlı (`?`). Eski dosya profil kaybı olmadan açılmalı.

## Review Focus

1. **0.1.0'dan kalan `state.json`** (yeni alanlar yok) açılınca profil ve olaylar aynen gelmeli, dosya "corrupt" diye kenara alınmamalı. Test: Task 1, `testDecodesV010State`.
2. **Anahtar yok ya da önbellek boş:** plan aynen kurulmalı, fotoğraf alanları nil olmalı. Test: Task 2, `testNoPhotosLeavesItemsUnassigned`.
3. **Aynı fotoğraf** bir planda iki bildirime atanmamalı, gösterilmiş bir fotoğraf tekrar atanmamalı. Test: Task 2, `testNoDuplicateWithinPlan` ve `testShownPhotosNotReassigned`.
4. **Yeniden planlama** (her açılışta olur) aynı öğenin fotoğrafını değiştirmemeli. Test: Task 2, `testReplanKeepsAssignment`.
5. **Önbellek temizliği** bekleyen bir bildirime atanmış dosyayı silmemeli. Ek dosyası yoksa bildirim eksiz kurulmalı. Test: Task 2, `testPruneKeepsReserved` (saf seçim fonksiyonu). Uygulama tarafı Task 5 cihaz kontrolünde.

---

### Task 1: İçerik ve durum alanları + bildirim başlığı

**Files:**
- Modify: `Sources/FYLCore/Content.swift` (Node, Button, QuestionGroup)
- Modify: `Sources/FYLCore/Planner.swift` (PlannedItem, `plan`, `harvestSent`)
- Modify: `Sources/FYLCore/State.swift` (Event)
- Test: `Tests/FYLCoreTests/PlannerTests.swift`, `Tests/FYLCoreTests/StateTests.swift`, `Tests/FYLCoreTests/ContentTests.swift`

**Interfaces:**
- Produces:
  - `Node.gist: String?`, `Node.imageQueries: [String]?`, `Button.icon: String?` (SF Symbol adı), `QuestionGroup.imageQueries: [String]?`
  - `PlannedItem.title: String?`, `PlannedItem.photoId: String?` (init'e varsayılanı nil olan parametreler olarak eklenir, mevcut çağrılar bozulmaz)
  - `Event.photoId: String?` (init'e varsayılan nil)
  - `harvestSent` ürettiği `.sent` olayına `photoId`'yi taşır.

- [ ] **Step 1: Dal aç:** `git checkout plan-1 && git checkout -b plan-2-gorsel`
- [ ] **Step 2: Başarısız testleri yaz**

```swift
// PlannerTests
func testTitles() {
    let day = items(on: "2026-11-10")
    XCTAssertEqual(day.first?.title, "Sabah")
    XCTAssertEqual(day.last?.title, "Görev")
    let ints = day.filter { $0.id.contains("-i") }
    XCTAssertEqual(ints.map(\.title), ints.indices.map { "Kesinti · \($0 + 1) / \(ints.count)" })
    XCTAssertNil(planned().last { $0.id == "plan-reopen" }?.title)
}
func testSetupDayTitles() {
    state.profile = nil; state.loopStart = nil; state.setupDate = d("2026-11-11 00:00")
    XCTAssertEqual(planned().map(\.title), ["Kurulum günü", "Kapanış"])   // s1, synthesis
}
func testHarvestCarriesPhoto() {
    let prev = [PlannedItem(id: "a", date: d("2026-11-10 10:00"), nodeId: "morning", text: "", photoId: "p1")]
    XCTAssertEqual(harvestSent(previous: prev, now: d("2026-11-10 11:00")).first?.photoId, "p1")
}
// StateTests: 0.1.0 biçiminde, yeni alan içermeyen bir state.json (profil + 1 sent olayı + 1 lastPlan öğesi) yaz,
// Store.load ile aç: profil.identity aynı, events.count == 1, lastPlan.first?.photoId == nil, dizinde "state-corrupt" dosyası yok.
func testDecodesV010State() throws { /* yukarıdaki gibi */ }
// ContentTests: yeni alanlı JSON çözülür; alanı olmayan eski içerik de çözülür.
func testOptionalVisualFields() throws { /* fixture'ı encode → gist/imageQueries/icon ekle → Content.load → değerler okunur */ }
```

- [ ] **Step 3: Push et, `test` iş akışının bu testlerde FAIL verdiğini gör.**
- [ ] **Step 4: Uygula.** Alanları ekle. `plan()` içinde başlık: kurulum gününde `nodeId == "synthesis" ? "Kapanış" : "Kurulum günü"`, döngüde `morning` → "Sabah", k'inci kesinti → `"Kesinti · \(k + 1) / \(n)"` (n o günün planlanan kesinti sayısı, chainUntil kaydırması numarayı değiştirmez), `quest_check` → "Görev", reopen → nil. `harvestSent` `photoId`'yi kopyalar.
- [ ] **Step 5: Push et, `test` ve `ios-build` yeşil.**
- [ ] **Step 6: Commit** `feat(core): bildirim başlığı, görsel içerik alanları, fotoğraf kimliği`

### Task 2: Fotoğraf ataması, tekrar önleme, yenileme önceliği (saf mantık)

**Files:**
- Create: `Sources/FYLCore/Photos.swift`
- Test: `Tests/FYLCoreTests/PhotosTests.swift`

**Interfaces:**
- Consumes: Task 1 `PlannedItem.photoId`, `Event.photoId`
- Produces:
  - `public func shownPhotos(_ state: AppState) -> Set<String>`: `.sent` olaylarındaki `photoId`'ler.
  - `public func assignPhotos(_ items: [PlannedItem], previous: [PlannedItem], available: [String: [String]], shown: Set<String>) -> [PlannedItem]`: `available` = düğüm id → önbellekteki fotoğraf id'leri (sıralı). Kural: önceki planda aynı `id`'li öğenin fotoğrafı hâlâ o düğümün `available` listesindeyse korunur. Yoksa listeden `shown`'da olmayan ve bu planda başka öğeye atanmamış ilk fotoğraf seçilir. Hiçbiri yoksa nil.
  - `public func reservedPhotos(_ plan: [PlannedItem]) -> Set<String>`
  - `public func pickFollowUpPhoto(nodeId: String, available: [String: [String]], shown: Set<String>, reserved: Set<String>) -> String?`
  - `public func refillOrder(queries: [String: [String]], available: [String: [String]], shown: Set<String>, reserved: Set<String>, target: Int, budget: Int) -> [String]`: sorgusu olan ve kullanılmamış fotoğraf sayısı (`available − shown − reserved`) `target`'tan az olan düğümler, en azı önce (eşitlikte id sırası), en çok `budget` tane.
  - `public func prunable(cached: [String], reserved: Set<String>, shown: Set<String>) -> [String]`: gösterilmiş ve rezerve olmayanlar.
  - `public func todaysMorningPhoto(_ state: AppState, now: Date, calendar: Calendar) -> String?`: bugünün mantıksal günündeki `morning` öğesinin (`lastPlan`) ya da `.sent` olayının `photoId`'si.

- [ ] **Step 1: Başarısız testleri yaz** (`PhotosTests`): `testAssignsFirstUnshown`, `testNoPhotosLeavesItemsUnassigned`, `testNoDuplicateWithinPlan` (aynı düğümden iki öğe, tek fotoğraf → biri nil), `testShownPhotosNotReassigned`, `testReplanKeepsAssignment` (aynı id, fotoğraf hâlâ mevcut → aynı; mevcut değil → yenisi), `testFollowUpSkipsReservedAndShown`, `testRefillOrderFewestFirstAndBudget` (3 düğüm, 0/1/5 kullanılmamış, target 3, budget 2 → ilk ikisi; sorgusu olmayan düğüm hiç yok), `testPruneKeepsReserved`, `testTodaysMorningPhotoFromPlanOrEvent`.
- [ ] **Step 2: Push et, FAIL gör.**
- [ ] **Step 3: `Photos.swift`'i yukarıdaki imzalarla uygula.**
- [ ] **Step 4: Push et, yeşil.**
- [ ] **Step 5: Commit** `feat(core): fotoğraf ataması ve önbellek kararları`

### Task 3: İçerik geçişi (tüm düğümler)

**Files:**
- Modify: `content/system.json` (`version` +1), `content/CHANGELOG.md`
- Test: `Tests/FYLCoreTests/ContentTests.swift`

**Interfaces:**
- Consumes: Task 1 alanları.
- Produces: gömülü içerikte her düğümde `gist` ve 2–3 `imageQueries`, her `protocolMorning` grubunda 2–3 `imageQueries`, butonlarda uygun `icon`.

- [ ] **Step 1: Başarısız test yaz:** `testBundledContentHasVisuals`: gömülü içerikte `reopen` dışındaki her düğümün `gist`'i boş değil ve en çok 40 karakter; `imageQueries` 2–3 eleman, boş eleman yok; her `protocolMorning` grubunda `imageQueries` 2–3; her `icon` boş değil.
- [ ] **Step 2: Push et, FAIL gör.**
- [ ] **Step 3: İçeriği yaz.** Gist: sorunun özü, soru biçiminde, en çok ~40 karakter ("Canlı mıydın, ölü müydün?"). Sorgular: spec §6.2 tonunda, somut ve fotoğraflanabilir, insan yüzü gerektirmeyen sahneler ("empty corridor", "mountain summit sunrise"). Simgeler: cevabın anlamına göre SF Symbols (`checkmark.circle`, `circle.lefthalf.filled`, `xmark.circle`, `sun.max`, `moon`, `questionmark.circle`, `pencil`, `arrow.right` gibi), ancak iOS 17'de var olanlar. CHANGELOG'a bir satır.
- [ ] **Step 4: Push et, yeşil.**
- [ ] **Step 5: Commit** `content: gist, görsel sorgular, buton simgeleri`

### Task 4: Unsplash, Keychain, önbellek ve yenileme

**Files:**
- Create: `App/Keychain.swift`, `App/Unsplash.swift`, `App/PhotoCache.swift`
- Modify: `App/FixYourLifeApp.swift` (AppModel: `refreshPhotos()`, replan içinde atama, BG görevi), `project.yml` (Info.plist: `UIBackgroundModes: [fetch]`, `BGTaskSchedulerPermittedIdentifiers: [com.meliksahhd.fixyourlife.photos]`)

**Interfaces:**
- Consumes: Task 2 fonksiyonları, Task 3 içeriği.
- Produces:
  - `enum Keychain { static func get(_ key: String) -> String?; static func set(_ key: String, _ value: String?) }`. Anahtar adı `"unsplashKey"`, `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock` (arka plan yenilemesi kilitliyken de okuyabilsin).
  - `struct UnsplashClient { let key: String; func search(_ query: String, page: Int) async throws -> [UnsplashPhoto]; func download(_ p: UnsplashPhoto, to url: URL) async throws; func validate() async -> Bool }`. `UnsplashPhoto` = `id`, `urls.raw`, `user.name`, `user.links.html`. `validate`: `per_page=1` arama, 200 → true. Zaman aşımı 20 sn.
  - `struct CachedPhoto: Codable { id, nodeId, photographer, profileURL: String }`
  - `final class PhotoCache` (dizin: Application Support/`photos/`; `<id>.jpg` + `<id>.json`): `func available() -> [String: [String]]` (düğüm → id, dosya adı sırası), `func fileURL(_ id: String) -> URL?` (dosya yoksa nil), `func meta(_ id: String) -> CachedPhoto?`, `func remove(_ ids: [String])`, `func store(_ p: UnsplashPhoto, nodeId: String, client: UnsplashClient) async throws`.
  - `AppModel.refreshPhotos() async`: anahtar yoksa hiçbir şey yapmaz. `refillOrder(target: 3, budget: 10)` sırasıyla her düğüm için rastgele bir sorgu, sayfa numarası `UserDefaults` `"unsplashPage.<nodeId>"` (sonuçlar tükenince +1, boş sayfa gelince 1'e döner). `shown` ve önbellekte olmayan sonuçlardan `target`'a tamamlayacak kadar indirir. HTTP 401/403/429 ya da ağ hatasında kalan düğümleri bırakır, hata yutar. Sonunda `prunable` olanları siler, `replan()` çağırır.
  - `replan()`: `plan(...)` sonrası `assignPhotos(items, previous: state.lastPlan, available: cache.available(), shown: shownPhotos(state))`. Ağ yok.
  - Kurulum soruları için `func setupPhoto(key: String, group: Int) -> String?`: `setupNotes["foto.<key>"]` varsa ve dosyası duruyorsa onu, yoksa grubun `imageQueries`'i için önbellekte `"setup.<group>"` düğüm adıyla tutulan fotoğraflardan ilk gösterilmemişi atar ve kaydeder. `refreshPhotos` kurulum günü yaklaşırken (`setupDate != nil`) `setup.<g>` sorgularını da `queries` sözlüğüne katar.
  - BG: uygulama açılışında `BGTaskScheduler.register(forTaskWithIdentifier: "com.meliksahhd.fixyourlife.photos")`. Görev `refreshPhotos()` çalıştırır, bitince bir sonrakini en erken 6 saat sonraya kurar. `.background`'a geçerken de istek kurulur.
  - Ön plan: `.active` → `replan()`, ardından `Task { await refreshPhotos() }`.

- [ ] **Step 1: `project.yml`'e Info.plist anahtarlarını ekle, dosyaları imzalarla yaz.**
- [ ] **Step 2: Push et, `ios-build` yeşil, `test` yeşil.**
- [ ] **Step 3: Commit** `feat(app): Unsplash önbelleği, Keychain, arka plan yenilemesi`

### Task 5: Bildirimde başlık, alt satır, grup, fotoğraf, buton simgesi

**Files:**
- Modify: `App/Notifications.swift`, `App/FixYourLifeApp.swift` (`receive`, `sendTestInterrupt`)

**Interfaces:**
- Consumes: Task 1 `title`, `gist`, `icon`; Task 2 `pickFollowUpPhoto`, `reservedPhotos`; Task 4 `PhotoCache.fileURL`.
- Produces:
  - `Notifier.apply(_ items: [PlannedItem], cache: PhotoCache, content: Content)`: her öğede `title`, `subtitle = content.nodes[nodeId]?.gist ?? ""`, `threadIdentifier` = öğe id'sinin ilk iki parçası (`plan-YYYYMMDD`; reopen için `"plan-reopen"`), `userInfo["title"]`, `userInfo["thread"]`. `photoId` varsa ve `fileURL` dönüyorsa dosya `tmp/<UUID>.jpg`'ye kopyalanır ve `UNNotificationAttachment(identifier: "foto", url:, options: nil)` eklenir. Kopyalama ya da ek oluşturma hata verirse ek atlanır, bildirim yine kurulur.
  - `Notifier.send(_ f: FollowUp, itemId: String, title: String?, thread: String?, photoURL: URL?, after: TimeInterval = 3)`: takip, kökün `title` ve `thread`'ini taşır.
  - `registerCategories`: `Button.icon` varsa `UNNotificationAction(identifier:title:options:icon: UNNotificationActionIcon(systemImageName:))`, metin girişli aksiyonda da aynı.
  - `AppModel.receive`: `userInfo`'dan `title` ve `thread`'i okur, takip için `pickFollowUpPhoto` ile fotoğraf seçer (ağ yok). Seçilen fotoğraf `Event(date: now, kind: .sent, nodeId: f.nodeId, text: f.text, itemId: nil, photoId: id)` olarak işlenir (`itemId: nil` olmalı: `handle()` kök tarihini `itemId` ile aradığı için).
  - `sendTestInterrupt` aynı yolu kullanır: "Kesinti · test" başlığı, varsa önbellekten `i_alive` fotoğrafı.

- [ ] **Step 1: Uygula.**
- [ ] **Step 2: Push et, `ios-build` yeşil.**
- [ ] **Step 3: Commit** `feat(app): bildirimde fotoğraf, başlık, alt satır ve grup`

### Task 6: Tema ve ekranlar

**Files:**
- Create: `App/Theme.swift`, `App/PhotoHeader.swift`
- Modify: `App/SetupView.swift`, `App/BoardView.swift`, `App/FixYourLifeApp.swift` (kökte `.preferredColorScheme(.dark)`, `.tint(Theme.accent)`)

**Interfaces:**
- Consumes: Task 2 `todaysMorningPhoto`, Task 4 `PhotoCache`, `AppModel.setupPhoto`, `Keychain`, `UnsplashClient.validate`.
- Produces:
  - `enum Theme { static let bg, text, secondary, card, accent: Color }` (Global Constraints'teki değerler). `struct Label11: View` ya da `Text.sectionLabel()`: 11 pt, yarı kalın, 1.6 harf aralığı, büyük harf, `secondary`.
  - `struct PhotoHeader: View { let photoId: String?; let height: CGFloat }`: önbellekte dosya yoksa `EmptyView`. Varsa `scaledToFill` ve kırpılmış görsel, alttan `Theme.bg`'ye geçen koyu degrade, sağ altta "Foto: <ad> / Unsplash" (11 pt). Yazıya dokununca `profileURL` Safari'de açılır (`?utm_source=fixyourlife&utm_medium=referral`).
  - Ekranlar maketlere göre (artboard 3 ve 4): `List`/`Form` yerine `ScrollView` + kartlar. Sorular ve kimlik cümlesi `.font(.system(.title, design: .serif))` ölçeğinde. Kartlar `Theme.card`, köşe 18. Ana buton açık zemin üzerinde koyu yazı, 56 pt. Tüm metinler Dynamic Type stilleriyle, dokunma alanları ≥ 44 pt.
  - `QuestionView`: üstte `PhotoHeader(photoId: model.setupPhoto(key:group:), height: ekranın ~1/3'ü)`, etiket "SABAH · <GRUP>" ve "k / 14", ilerleme çizgisi, serif soru, italik açıklama (`questions` metnindeki ilk "?"tan sonrası, yoksa yok), alt çizgili not alanı, "Kâğıda yazdım" ve "Geri".
  - `BoardView`: üstte `PhotoHeader(photoId: todaysMorningPhoto(...))`, serif kimlik ("Ben <kimlik> tipte biriyim.", kimlik kırmızı), boss kartı (kalan gün + 30 günlük ilerleme çubuğu, vurgu rengi), görevler (mevcut döngü ve simgeler, dokununca `.sensoryFeedback(.selection, trigger:)`), yan yana Kazanma/Risk kartları (Risk kartı zemini `#1E1110`, etiketi vurgu rengi), 1 yıl kartı, altta düşman ve kurallar. Mevcut düzenleme sayfaları aynı davranışla kalır.
  - Diğer kurulum ekranları (karşılama, bekleme, kimlik, gün içi, sentez) ve sayfalar: aynı tema. `Form` kalabilir, ama `.scrollContentBackground(.hidden)`, `Theme.bg` zemin, `Theme.card` satır zemini, serif başlıklar.
  - Ayarlar'a "Fotoğraflar" bölümü: anahtar yoksa "Fotoğraflar kapalı", `SecureField("Unsplash Access Key")`, "Kaydet" → `validate()` → doğruysa `Keychain.set` ve `Task { await refreshPhotos() }`, değilse "Anahtar geçersiz". Anahtar varsa "Fotoğraflar açık · önbellekte N fotoğraf" ve "Anahtarı sil".
  - Oyun tahtasında anahtar yoksa kapatılabilir bir ipucu kartı: "Fotoğrafları açmak için Ayarlar'a Unsplash anahtarını ekle." (`@AppStorage("fotoIpucuKapali")`).

- [ ] **Step 1: Uygula.**
- [ ] **Step 2: Push et, `ios-build` yeşil.**
- [ ] **Step 3: Commit** `feat(app): koyu tema, fotoğraflı ekranlar, anahtar ayarı`

### Task 7: Simge

**Files:**
- Modify: `App/Assets.xcassets/AppIcon.appiconset/icon.png`

- [ ] **Step 1:** Scratchpad'deki tek seferlik bir Python/PIL betiğiyle 1024×1024 PNG üret (betik repoya girmez): zemin `#111111` (tam kare, köşesiz, saydamlıksız), ortalanmış açık çerçeve `#EAEAEA` dış kenarı 592 px, kalınlığı 80 px, ortada kırmızı kare `#DD3C33` 188 px.
- [ ] **Step 2: Görüntüyü aç ve gözle kontrol et, push et, `ios-build` yeşil.**
- [ ] **Step 3: Commit** `feat: daha kalın simge`

### Task 8: Sürüm, derleme, cihazda kontrol

**Files:**
- Modify: `project.yml` (`MARKETING_VERSION: 0.2.0`), `docs/kurulum.md` (Unsplash anahtarı adımı ve yeni kontrol satırları)

- [ ] **Step 1:** Sürümü yükselt, `docs/kurulum.md`'ye "Unsplash anahtarı" adımını ekle (unsplash.com/developers → uygulama → Access Key → uygulamada Ayarlar → Fotoğraflar). Kontrol listesine şunları ekle: fotoğraflı test bildirimi, başlık ve alt satır, günün bildirimlerinin tek grupta olması, oyun tahtası fotoğrafı ve atıf, uçak modunda bildirimin fotoğrafsız gelmesi.
- [ ] **Step 2:** Push et, `test` ve `ios-build` yeşil. `build-2` etiketini at. Codemagic'te derleme kendiliğinden başlamazsa `plan-2-gorsel` dalından elle başlat. TestFlight'ta 0.2.0'ın göründüğünü doğrula.
- [ ] **Step 3:** Kullanıcı anahtarı girer, kontrol listesini cihazda yürütür. Beğenilmeyen fotoğraf temaları Task 3 içeriğinde düzeltilir.
- [ ] **Step 4: Commit** `chore: 0.2.0`

---

## Self-review notları

- Spec kapsamı: §6.1 → Task 4 + 6 (ayar, atıf). §6.2 → Task 3. §6.3 → Task 2 + 4. §6.4 → Task 1 + 5. §6.5 → Task 6. §6.6 → Task 7. §7b.1 → Task 1/2/4/6. §7b.2 → Task 6. §7b.3 → Task 1/2. §7b.4 → Task 4/6. §7b.5 → Task 1/3. §7b.6 → Task 1/5.
- Hedef dışı (§3): içerik eklentisi, özel ses, yazı katmanı yok.
