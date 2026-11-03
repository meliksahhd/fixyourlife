# FixYourLife Plan 1: Çekirdek (telefonda çalışan ilk sürüm) — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kurulum günü + günlük döngü (sabah, butonlu kesinti soruları ve takipleri, akşam kapanışı) + oyun tahtası iPhone'da TestFlight üzerinden çalışır; tüm cevaplar ileride ayna için kaydedilir.

**Architecture:** Tüm mantık (içerik modeli, doğrulama, şablon doldurma, planlayıcı, senaryo motoru, kalıcılık) yalnızca Foundation kullanan bir SwiftPM kütüphanesinde (`FYLCore`) durur. Bu kütüphane GitHub Actions'ta Linux üzerinde `swift test` ile dakikalar içinde test edilir. iOS katmanı (`App/`) ince bir kabuktur: SwiftUI ekranları + `UNUserNotificationCenter` köprüsü. XcodeGen ile proje bulutta üretilir, Codemagic ile TestFlight'a gider.

**Tech Stack:** Swift 5.10 dil modu (swift-tools-version 5.10), XCTest, SwiftUI, UserNotifications, iOS 17+, XcodeGen, Codemagic, GitHub Actions (`swift:6.1` container).

**Spec:** `docs/superpowers/specs/2026-11-03-fixyourlife-design.md`

## Kapsam: bu plan / Plan 2

Spec tek planda telefona ulaşamayacak kadar geniş. Bu plan, telefonda kullanılabilir ilk sürümü üretir. **Plan 2** (bu plan bittikten ve ~1 hafta kullanıldıktan sonra yazılacak) şunları kapsar: Ayna ekranı ve haftalık ayna (§6.6), tırmanma kuralları (§6.5), 30 günlük boss değerlendirmesi ve yıllık yenileme (§6.3), uzaktan içerik güncelleme ve "önceki sürüme dön" (§7, §9b.4), alışkanlık/anekdot ekleme (§6.7), dışa aktarma (§10). Plan 1 bunların ihtiyaç duyacağı **ham veriyi şimdiden kaydeder** (gönderilen bildirimler, cevaplar, görev sonuçları). Böylece Plan 2 geldiğinde ilk günden itibaren geçmiş veri hazır olur.

## Global Constraints

- Arayüz ve tüm içerik Türkçe; kod tanımlayıcıları İngilizce.
- Minimum iOS 17.0. Bundle ID: `com.meliksahhd.fixyourlife`. Görünen ad: `FixYourLife`.
- Kişisel cevaplar yalnızca cihazda kalır. Ağ isteği yok (Plan 1'de hiç ağ kodu yok).
- `FYLCore` yalnızca `Foundation` import eder (UIKit/UserNotifications/SwiftUI yasak), aksi hâlde Linux CI kırılır.
- Varsayılan saatler: sabah `10:00`, akşam kapanışı `23:30`, kesintiler sabah+60 dk ile akşam−30 dk arası (varsayılanla 11:00–23:00), günde 5–6 kesinti, aralar en az 75 dk. Sabahtan önce ve akşamdan sonra planlı bildirim yok (sessiz saatler bundan çıkar).
- Kurulum günü kesinti saatleri (makaledeki sabit saatler): 11:00, 13:30, 15:15, 17:00, 19:30, 21:00. Derin sorular: 12:30, 16:15, 18:30. Sentez hatırlatması: 22:00.
- Takip zinciri en fazla 3 bildirim (kök dahil). Zincir sürerken 20 dk içinde planlı kesinti gelmez.
- Kilit ekranı yer tutucu metni: `Sana bir sorum var`.
- Ton: doğrudan, hesap soran; boş övgü yok (spec §4).
- Repo **public** (spec §9b.4): içinde sır ve kişisel veri yok. `content/sources/` (makalenin tam metni, telif) **gitignore'da**.
- Bekleyen bildirim sayısı her zaman ≤ 60 (iOS sınırı 64; 4'ü takip bildirimlerine ayrıldı).

## Review Focus

1. **Kullanıcının boş bıraktığı isteğe bağlı alan:** Bu alanı kullanan bir soru asla `{enemy}` gibi ham değişkenle ya da boş tırnakla gelmemeli; o soru havuzdan çıkmalı. → Task 3 `testRenderReturnsNilWhenVarEmpty`, Task 5 `testSkipsInterruptWithEmptyVar`.
2. **Gece yarısından sonra cevap:** 23:30 kapanışına 00:20'de cevap verilirse sonuç önceki güne yazılmalı. → Task 4 `testLogicalDay`, Task 6 `testQuestStatusAcrossMidnight`.
3. **Uygulama günlerce açılmazsa:** Bildirimler sessizce bitmemeli; pencerenin sonunda "aç" hatırlatması olmalı. → Task 5 `testWindowCoversSixDaysPlusReopen`.
4. **Kurulum günü geç başlarsa:** Geçmiş sabit saatler atlanmalı, gelecektekiler kalmalı. → Task 5 `testSetupDaySkipsPastTimes`.
5. **Bozuk durum dosyası:** Okunamayan `state.json` üzerine yazılıp veri yok edilmemeli; kenara alınmalı. → Task 4 `testCorruptFileIsPreserved`. Aynı aileden: içerik değişince eski bildirimdeki düğüm/buton yoksa çökme olmamalı → Task 6 `testUnknownNodeOrButtonIgnored`.

---

## Dosya haritası

```
Package.swift                         FYLCore kütüphanesi + testleri
Sources/FYLCore/Random.swift          SplitMix64 (tohumlu, platformdan bağımsız RNG)
Sources/FYLCore/Content.swift         system.json modeli, doğrulama, şablon doldurma
Sources/FYLCore/State.swift           Profile, Settings, Event, AppState, Store, logicalDay, questStatus
Sources/FYLCore/Planner.swift         PlannedItem, plan(), harvestSent()
Sources/FYLCore/Engine.swift          Reply, FollowUp, handle()
Tests/FYLCoreTests/Helpers.swift      Istanbul takvimi, d("2026-11-10 14:00")
Tests/FYLCoreTests/Fixture.swift      küçük geçerli içerik JSON'u + örnek Profile
Tests/FYLCoreTests/*Tests.swift       her kaynak dosya için bir test dosyası
content/system.json                   gerçek Türkçe içerik (uygulamaya gömülür)
content/CHANGELOG.md
App/FixYourLifeApp.swift              @main, AppModel (durum, kaydet, yeniden planla)
App/Notifications.swift               Notifier: kategoriler, zamanlama, delegate
App/SetupView.swift                   karşılama, sabah protokolü, akşam sentezi
App/BoardView.swift                   oyun tahtası + ayarlar
project.yml                           XcodeGen
codemagic.yaml
.github/workflows/test.yml
docs/kurulum.md                       kullanıcının tek seferlik Apple/Codemagic adımları
```

---

### Task 1: Repo, paket iskeleti, Linux CI

**Files:**
- Create: `.gitignore`, `Package.swift`, `Sources/FYLCore/Random.swift`, `Tests/FYLCoreTests/Helpers.swift`, `Tests/FYLCoreTests/RandomTests.swift`, `.github/workflows/test.yml`

**Interfaces:**
- Produces: `public struct SplitMix64: RandomNumberGenerator { public init(seed: UInt64); public mutating func next() -> UInt64 }`; test yardımcıları `let cal: Calendar` (gregorian, `Europe/Istanbul`) ve `func d(_ s: String) -> Date` (`"yyyy-MM-dd HH:mm"`, aynı saat dilimi).

- [ ] **Step 1:** `git init`, `main` dalı. `.gitignore`: `.build/`, `*.xcodeproj`, `content/sources/`, `.DS_Store`.
- [ ] **Step 2:** `Package.swift`: tools 5.10, `platforms: [.iOS(.v17), .macOS(.v14)]`, library `FYLCore`, testTarget `FYLCoreTests`.
- [ ] **Step 3: Failing test** `RandomTests.swift`

```swift
func testKnownFirstValue() { var r = SplitMix64(seed: 0); XCTAssertEqual(r.next(), 0xE220A8397B1DCDAF) }
func testSameSeedSameSequence() {
    var a = SplitMix64(seed: 20261110), b = SplitMix64(seed: 20261110)
    XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
}
```

- [ ] **Step 4:** `SplitMix64`'ü standart algoritmayla yaz (state += 0x9E3779B97F4A7C15; xor-shift-multiply 30/27/31).
- [ ] **Step 5:** `.github/workflows/test.yml`: push ve PR'da, `runs-on: ubuntu-latest`, `container: swift:6.1`, `actions/checkout@v4`, `swift test`.
- [ ] **Step 6: Kullanıcıya sor, onay alınca** `gh repo create meliksahhd/fixyourlife --public --source . --push`. Repo herkese açık olacak, bu yüzden göndermeden önce `git status` ile `content/sources/` dosyasının listede olmadığını doğrula.
- [ ] **Step 7:** Doğrula: `gh run watch` → test işi yeşil.
- [ ] **Step 8:** Commit `chore: paket iskeleti ve Linux CI`.

---

### Task 2: iOS kabuğu + Codemagic → TestFlight hattı

Bu görev erken geliyor çünkü kullanıcının Apple tarafında yapacağı tek seferlik adımlar zaman alıyor. Mantık görevleri (3–6) bu sırada paralel ilerleyebilir.

**Files:**
- Create: `project.yml`, `codemagic.yaml`, `App/FixYourLifeApp.swift`, `docs/kurulum.md`

**Interfaces:**
- Consumes: `FYLCore` (yerel paket).
- Produces: `FixYourLife` scheme'li, TestFlight'a giden bir derleme; `content/system.json` uygulama paketine kaynak olarak gömülü (Task 3'te gerçek içerikle dolar, şimdilik `{}` yeterli).

- [ ] **Step 1:** `project.yml`: proje `FixYourLife`, `options.deploymentTarget.iOS: "17.0"`, `packages: FYLCore: {path: .}`, iPhone app target `FixYourLife` (sources `App`, resources `content/system.json`, dependency `package: FYLCore`). Settings: `PRODUCT_BUNDLE_IDENTIFIER: com.meliksahhd.fixyourlife`, `MARKETING_VERSION: 0.1.0`, `CURRENT_PROJECT_VERSION: 1`, `VERSIONING_SYSTEM: apple-generic`, `TARGETED_DEVICE_FAMILY: 1`, `GENERATE_INFOPLIST_FILE: YES`. Info anahtarları: `CFBundleDisplayName: FixYourLife`, `UILaunchScreen: {}`, `ITSAppUsesNonExemptEncryption: false`.
- [ ] **Step 2:** `App/FixYourLifeApp.swift`: `@main` ve `Text("FixYourLife")` gösteren tek bir ekran.
- [ ] **Step 3:** `codemagic.yaml`, workflow `ios-testflight`: `instance_type: mac_mini_m2`, `max_build_duration: 30`, `integrations.app_store_connect: fyl_asc`, `environment.ios_signing {distribution_type: app_store, bundle_identifier: com.meliksahhd.fixyourlife}`, `vars.APP_STORE_APPLE_ID` (kullanıcıdan gelecek sayı), `xcode: latest`. Tetikleyici: yalnızca `build-*` etiketleri (her push'ta derlenmez, böylece 500 dk/ay ücretsiz kota korunur). Betikler: `brew install xcodegen && xcodegen generate` → `xcode-project use-profiles` → `agvtool new-version -all $(($(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID") + 1))` → `xcode-project build-ipa --project FixYourLife.xcodeproj --scheme FixYourLife`. Publishing: `app_store_connect {auth: integration, submit_to_testflight: true}`.
- [ ] **Step 4:** `docs/kurulum.md`: Kullanıcının yapacağı adımları Türkçe ve numaralı listele:
  1. developer.apple.com → Identifiers → `com.meliksahhd.fixyourlife` kaydı.
  2. App Store Connect → Uygulamalar → + → "FixYourLife" kaydı (bu bundle ID ile). Apple ID numarasını bana ilet.
  3. App Store Connect → Kullanıcılar ve Erişim → Entegrasyonlar → App Store Connect API → **App Manager** yetkili anahtar oluştur, `.p8` dosyasını indir. Issuer ID ve Key ID'yi not et.
  4. codemagic.io → GitHub ile giriş → `fixyourlife` reposunu ekle.
  5. Codemagic → Team/Personal settings → Integrations → Developer Portal → anahtarı **`fyl_asc`** adıyla ekle.
  6. Codemagic → Code signing identities → iOS certificates → "Generate certificate" (App Store dağıtımı). Ardından iOS provisioning profiles → "Fetch profiles".
  7. iPhone'a TestFlight uygulamasını kur. App Store Connect → TestFlight → İç test grubu oluştur, kendini ekle.

  Her adıma "Bitti mi? Ekranda şunu görmelisin: …" satırı ekle.
- [ ] **Step 5:** Kullanıcı 1–7. adımları bitirince `APP_STORE_APPLE_ID`'yi yaz. Commit `feat: iOS kabuğu ve Codemagic hattı`, push. Ardından `git tag build-1 && git push origin build-1`.
- [ ] **Step 6:** Doğrula: Codemagic derlemesi yeşil, TestFlight'ta 0.1.0 (n) görünüyor, kullanıcının iPhone'unda "FixYourLife" yazısı açılıyor. Kırmızıysa: log'u oku, `systematic-debugging` kullan.

---

### Task 3: İçerik modeli, doğrulama, şablon doldurma + gerçek Türkçe içerik

**Files:**
- Create: `Sources/FYLCore/Content.swift`, `Tests/FYLCoreTests/Fixture.swift`, `Tests/FYLCoreTests/ContentTests.swift`, `content/system.json`, `content/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 4'ün `Profile` tipi. Bu görevde önce `Profile`'ı `State.swift` içinde tanımla; Task 4 dosyanın geri kalanını ekler.
- Produces:

```swift
public enum Role: String, Codable { case interrupt, followup, setup, system }
public struct Button: Codable, Equatable { public var title: String; public var tag: String; public var next: String?; public var input: Bool?; public var foreground: Bool? }
public struct Node: Codable, Equatable { public var role: Role; public var texts: [String]; public var buttons: [Button]; public var perQuest: Bool?; public var after: String? }
public struct TimedNode: Codable, Equatable { public var time: String /* "HH:mm" */; public var node: String }
public struct QuestionGroup: Codable, Equatable { public var title: String; public var questions: [String] }
public struct Content: Codable, Equatable {
    public var version: Int; public var placeholder: String; public var reopenText: String
    public var protocolMorning: [QuestionGroup]; public var setupSchedule: [TimedNode]; public var nodes: [String: Node]
    public static func load(_ data: Data) throws -> Content   // decode + validate; validate hatası varsa ContentError.invalid([String]) fırlatır
    public func validate() -> [String]                        // boş = geçerli; her hata okunur bir Türkçe/İngilizce cümle, ilgili düğüm id'sini içerir
}
public func render(_ text: String, profile: Profile?, questIndex: Int?) -> String?
public struct Profile: Codable, Equatable {   // State.swift
    public var identity, antiVision, vision, enemy, yearGoal, monthProject, whyStuck: String
    public var quests: [String]; public var constraints: [String]; public var monthStart: Date
}
```

Şablon değişkenleri: `{identity} {antiVision} {vision} {enemy} {yearGoal} {monthProject} {quest}` (`quests[questIndex]`), `{todayQuests}` (`quests` `", "` ile birleşik), `{constraints}` (`", "` ile birleşik). Değişkenin değeri boş ya da yoksa `render` → `nil` döner.

`validate` kuralları: zorunlu id'ler `morning`, `quest_check`, `day_rating`, `reopen`, `synthesis` var olmalı. Her `next`/`after` var olan bir düğümü göstermeli. Her düğümde 1–4 buton ve ≥1 metin olmalı. `interrupt` düğümlerinde ≥3 metin olmalı. `setup` düğümlerinde `{` geçmemeli. Bilinmeyen değişken (`{foo}`) olmamalı. `setupSchedule` saatleri `HH:mm` biçiminde olmalı ve düğümleri var olmalı. `next` zincirinde döngü olmamalı ve kök (interrupt/setup/system) dahil zincir derinliği ≤3 olmalı.

- [ ] **Step 1:** `Fixture.swift` içine `let fixtureJSON` yaz (aşağıdaki JSON aynen). Ayrıca `let profile = Profile(identity: "Yaratıcı biri", antiVision: "Masa başında çürüyen", vision: "Kendi işini yapan", enemy: "Onay ihtiyacı", yearGoal: "İlk ürün", monthProject: "Uygulamayı bitir", whyStuck: "", quests: ["Oku", "Yaz"], constraints: ["Uyku"], monthStart: d("2026-11-10 00:00"))` ve `func fixture() -> Content` ekle.

```json
{"version":1,"placeholder":"Sana bir sorum var","reopenText":"Uygulamayı aç",
 "protocolMorning":[{"title":"Acı","questions":["S1?"]}],
 "setupSchedule":[{"time":"11:00","node":"s1"},{"time":"22:00","node":"synthesis"}],
 "nodes":{
  "morning":{"role":"system","texts":["{identity}: {todayQuests}"],"buttons":[{"title":"Başlıyorum","tag":"basliyorum"},{"title":"Değiştir","tag":"degistir","foreground":true}]},
  "quest_check":{"role":"system","texts":["Görev: {quest}"],"perQuest":true,"after":"day_rating","buttons":[{"title":"Yaptım","tag":"yaptim"},{"title":"Kısmen","tag":"kismen"},{"title":"Yapmadım","tag":"yapmadim"}]},
  "day_rating":{"role":"system","texts":["Gün?"],"buttons":[{"title":"Canlı","tag":"canli"},{"title":"Ölü","tag":"olu"}]},
  "reopen":{"role":"system","texts":["Aç"],"buttons":[{"title":"Aç","tag":"ac","foreground":true}]},
  "synthesis":{"role":"setup","texts":["Sentez"],"buttons":[{"title":"Aç","tag":"ac","foreground":true}]},
  "s1":{"role":"setup","texts":["Neden kaçıyorsun?"],"buttons":[{"title":"Düşündüm","tag":"dusundum"}]},
  "i1":{"role":"interrupt","texts":["A1","A2","A3"],"buttons":[{"title":"Nefret","tag":"nefret","next":"f1"},{"title":"İstediğim","tag":"istedigim_hayat"}]},
  "i2":{"role":"interrupt","texts":["B1","B2","B3"],"buttons":[{"title":"Not","tag":"not","input":true}]},
  "i3":{"role":"interrupt","texts":["{enemy} 1","{enemy} 2","{enemy} 3"],"buttons":[{"title":"Evet","tag":"evet"}]},
  "f1":{"role":"followup","texts":["Neyden kaçıyorsun?"],"buttons":[{"title":"Zor işten","tag":"kaciyordum","next":"f2"}]},
  "f2":{"role":"followup","texts":["{identity} ne yapardı?"],"buttons":[{"title":"Yapıyorum","tag":"yapiyorum"}]}}}
```

- [ ] **Step 2: Failing tests** `ContentTests.swift`:

```swift
func testFixtureIsValid() { XCTAssertEqual(fixture().validate(), []) }
func testUnknownNextIsInvalid() { var c = fixture(); c.nodes["i1"]!.buttons[0].next = "nope"; XCTAssertTrue(c.validate().contains { $0.contains("nope") }) }
func testDepthOver3IsInvalid() { var c = fixture(); c.nodes["f3"] = c.nodes["f1"]!; c.nodes["f3"]!.buttons[0].next = nil; c.nodes["f2"]!.buttons[0].next = "f3"; XCTAssertFalse(c.validate().isEmpty) }
func testCycleIsInvalid() { var c = fixture(); c.nodes["f2"]!.buttons[0].next = "f1"; XCTAssertFalse(c.validate().isEmpty) }
func testFiveButtonsInvalid() { var c = fixture(); c.nodes["i2"]!.buttons = Array(repeating: c.nodes["i2"]!.buttons[0], count: 5); XCTAssertFalse(c.validate().isEmpty) }
func testInterruptNeedsThreeVariants() { var c = fixture(); c.nodes["i1"]!.texts = ["A1", "A2"]; XCTAssertFalse(c.validate().isEmpty) }
func testSetupNodeCannotUseTemplate() { var c = fixture(); c.nodes["s1"]!.texts = ["{identity}"]; XCTAssertFalse(c.validate().isEmpty) }
func testUnknownVariableInvalid() { var c = fixture(); c.nodes["i2"]!.texts[0] = "{foo}"; XCTAssertFalse(c.validate().isEmpty) }
func testLoadThrowsOnInvalid() { var c = fixture(); c.nodes["i1"]!.buttons[0].next = "nope"; XCTAssertThrowsError(try Content.load(JSONEncoder().encode(c))) }
func testRenderFillsVars() { XCTAssertEqual(render("{identity} / {quest} / {todayQuests}", profile: profile, questIndex: 1), "Yaratıcı biri / Yaz / Oku, Yaz") }
func testRenderReturnsNilWhenVarEmpty() { var p = profile; p.enemy = ""; XCTAssertNil(render("{enemy} kazandı mı?", profile: p, questIndex: nil)) }
func testRenderNilWithoutProfile() { XCTAssertNil(render("{identity}", profile: nil, questIndex: nil)); XCTAssertEqual(render("Düz", profile: nil, questIndex: nil), "Düz") }
```

- [ ] **Step 3:** `swift test --filter ContentTests` → FAIL (tipler yok).
- [ ] **Step 4:** `Content.swift`'i yaz. Derinlik/döngü kontrolü: her kök düğümden DFS yap, ziyaret yığınında tekrar görülen düğüm döngü demek. `perQuest` düğümünün kendine dönüşü `next` değil motor kuralı olduğu için kontrole dahil değil.
- [ ] **Step 5:** `swift test --filter ContentTests` → PASS.
- [ ] **Step 6:** `content/system.json`'u Türkçe yaz. Kaynak: `content/sources/` altındaki makale (yerelde duruyor). Yazımda makaleye sadık kal ve Dan Koe tonunu koru: doğrudan, kısa, boş övgü yok.
  - `protocolMorning`: 3 grup ("Acıyı gör" 4 soru, "Anti-vizyon" 7 soru, "Vizyon (MVP)" 3 soru). Makaledeki 14 sorunun sadık çevirisi.
  - `setupSchedule`: 11:00 `setup_avoid`, 12:30 `setup_deep_identity`, 13:30 `setup_filmed`, 15:15 `setup_direction`, 16:15 `setup_deep_safety`, 17:00 `setup_pretend`, 18:30 `setup_deep_smallest`, 19:30 `setup_protect`, 21:00 `setup_alive`, 22:00 `synthesis`. Setup düğümlerinin butonları: "Düşündüm" / "Şimdi değil" + uygun olanlarda kısa sınıflama. Bu düğümlerde şablon yok; derin kimlik sorusu "kurulum sabahı yazdığın kimlik" diye atıf yapar.
  - Günlük havuz (`interrupt`, her biri ≥3 varyant): makaledeki 6 kesinti sorusu + 3 derin soru (`{identity}` kullanabilir) + en az 4 şablon soru (`{antiVision}`, `{identity}`, `{enemy}`, `{vision}`). Spec §6.4'teki 15:15 akışını `followup` düğümleriyle birebir kur. En az 3 kök sorunun takip dalı olsun.
  - `morning` (`{identity}`, `{todayQuests}`; butonlar "Bu kişiyim, başlıyorum" / "Görevleri değiştir" foreground), `quest_check` (perQuest, after `day_rating`), `day_rating` ("Bugün en canlı ne zamandın?" tarzı; 2–4 buton), `reopen` (foreground "Aç"), `synthesis` (foreground "Sentezi aç").
  - Etiketler snake_case ve ASCII olsun (`kaciyordum`, `istedigim_hayat`, `kimlik_korumasi`, `bilinmiyor` …).
- [ ] **Step 7: Failing test** (gerçek dosya): `testBundledContentIsValid`: `URL(fileURLWithPath: #filePath)` üzerinden 3 üst klasöre çık, `content/system.json`'u oku. `Content.load` hata fırlatmamalı. Ayrıca `profile` ile her düğümün her metni `render` ile nil olmayan ve `{` içermeyen bir sonuç vermeli (`quest_check` için `questIndex: 0`). Önce dosyada bilerek bir hata bırakıp testin kırıldığını gör, sonra düzelt.
- [ ] **Step 8:** `swift test` → PASS. `content/CHANGELOG.md`: `## v1 — 2026-11-03` başlığı altında ilk içerik ve kaynak makale.
- [ ] **Step 9:** Commit `feat: içerik modeli, doğrulama ve Türkçe v1 içerik`.

---

### Task 4: Durum, kalıcılık, mantıksal gün

**Files:**
- Modify: `Sources/FYLCore/State.swift`
- Create: `Tests/FYLCoreTests/StateTests.swift`

**Interfaces:**
- Produces:

```swift
public struct Settings: Codable, Equatable { public var morning = "10:00"; public var evening = "23:30" }
public enum EventKind: String, Codable { case sent, answered, note }
public struct Event: Codable, Equatable { public var date: Date; public var kind: EventKind; public var nodeId: String; public var tag: String?; public var text: String?; public var questIndex: Int?; public var itemId: String? }
public struct AppState: Codable, Equatable {
    public var profile: Profile? = nil; public var settings = Settings()
    public var setupDate: Date? = nil      // planlanmış kurulum günü (gün başı); sentez kaydedilince nil
    public var loopStart: Date? = nil      // günlük döngünün başladığı mantıksal gün
    public var setupNotes: [String: String] = [:]  // sabah protokolü notları, anahtar "grup.soru" ("0.2")
    public var events: [Event] = []; public var lastPlan: [PlannedItem] = []; public var chainUntil: Date? = nil
    public init() {}
}
public func logicalDay(_ date: Date, calendar: Calendar) -> Date            // startOfDay(date − 4 saat)
public func questStatus(_ state: AppState, on day: Date, calendar: Calendar) -> [String?]   // her görev için o mantıksal günün en son "answered" quest_check/board etiketi
public enum Store {
    public static func load(_ url: URL) -> AppState    // dosya yoksa AppState(); bozuksa dosyayı "state-corrupt-<unix>.json" olarak yeniden adlandırır, AppState() döner
    public static func save(_ state: AppState, to url: URL) throws   // .atomic
}
```

Not: `PlannedItem` Task 5'te tanımlanır. Bu görevde derlenmesi için önce `Planner.swift` içine yalnızca o struct'ı koy (bkz. Task 5 Interfaces).

- [ ] **Step 1: Failing tests**:

```swift
func testLogicalDay() { XCTAssertEqual(logicalDay(d("2026-11-11 00:30"), calendar: cal), d("2026-11-10 00:00")); XCTAssertEqual(logicalDay(d("2026-11-11 04:30"), calendar: cal), d("2026-11-11 00:00")) }
func testRoundTrip() throws { var s = AppState(); s.profile = profile; s.events = [Event(date: d("2026-11-10 12:00"), kind: .answered, nodeId: "i1", tag: "nefret", text: nil, questIndex: nil, itemId: "x")]; let u = tmpURL(); try Store.save(s, to: u); XCTAssertEqual(Store.load(u), s) }
func testMissingFileGivesFresh() { XCTAssertEqual(Store.load(tmpURL()), AppState()) }
func testCorruptFileIsPreserved() throws { let u = tmpURL(); try Data("çöp".utf8).write(to: u); XCTAssertEqual(Store.load(u), AppState()); let siblings = try FileManager.default.contentsOfDirectory(atPath: u.deletingLastPathComponent().path); XCTAssertTrue(siblings.contains { $0.hasPrefix("state-corrupt-") }) }
```
`tmpURL()`: her çağrıda yeni bir geçici klasörde `state.json` (Helpers.swift'e ekle).

- [ ] **Step 2:** `swift test --filter StateTests` → FAIL.
- [ ] **Step 3:** Implement. JSON tarih stratejisi `.iso8601`, encoder ve decoder'da aynı olsun.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat: uygulama durumu ve dosya kalıcılığı`.

---

### Task 5: Planlayıcı

**Files:**
- Modify: `Sources/FYLCore/Planner.swift`
- Create: `Tests/FYLCoreTests/PlannerTests.swift`

**Interfaces:**
- Consumes: `Content`, `render`, `AppState`, `logicalDay`, `SplitMix64`.
- Produces:

```swift
public struct PlannedItem: Codable, Equatable { public var id: String; public var date: Date; public var nodeId: String; public var text: String; public var questIndex: Int? }
public func plan(now: Date, state: AppState, content: Content, calendar: Calendar, days: Int = 6) -> [PlannedItem]   // tarihe göre sıralı, yalnızca date > now
public func harvestSent(previous: [PlannedItem], now: Date) -> [Event]   // date <= now olan her öğe için kind .sent, itemId = id, date = item.date
```

Kurallar:
- Pencere: `logicalDay(now)` dahil `days` gün.
- **Kurulum günü** (`day == state.setupDate`): yalnızca `content.setupSchedule` öğeleri. id `plan-yyyyMMdd-sN`.
- **Günlük gün** (`profile != nil`, `loopStart != nil`, `day >= loopStart`, kurulum günü değil): `morning` (sabah saati), kesintiler, `quest_check` (akşam saati, `questIndex: 0`). id'ler `plan-yyyyMMdd-m`, `-iN`, `-e`.
- Kesintiler: gün tohumu `SplitMix64(seed: UInt64(yyyyMMdd))`. Sıra şöyle: önce `n = Int.random(in: 5...6)`, sonra saatler, sonra düğüm ve varyant seçimi. Saat algoritması:
  ```
  start = sabah+60, end = akşam−30 (dakika); gap = 75
  while n > 0 && (n-1)*gap > end-start { n -= 1 }
  free = (end-start) - (n-1)*gap
  offsets = (0..<n).map { _ in Int.random(in: 0...free, using: &rng) }.sorted()
  time_k = start + offsets[k] + k*gap
  ```
  Düğüm seçimi: `role == .interrupt` olan ve en az bir varyantı `render` ile nil dönmeyen düğümler, id'ye göre sıralı. Bu havuzdan tekrar olmadan seç; havuz biterse yeniden doldur. Varyant da yalnızca render edilebilenler arasından rastgele seçilir.
- `chainUntil > now` ise `[now, chainUntil)` aralığına düşen kesintiler `chainUntil + k dk` saatine kayar.
- `profile != nil` ise pencerenin ertesi günü sabah saatine `plan-reopen` öğesi eklenir (`nodeId "reopen"`, `text content.reopenText`).
- Toplam ≤ 60.

- [ ] **Step 1: Failing tests** (ortak kurulum: `state.profile = profile; state.loopStart = d("2026-11-10 00:00")`, `now = d("2026-11-10 09:00")`):

```swift
func testDailyDayShape() { let day = items(on: "2026-11-10"); XCTAssertEqual(day.first?.nodeId, "morning"); XCTAssertEqual(day.first?.date, d("2026-11-10 10:00")); XCTAssertEqual(day.last?.nodeId, "quest_check"); XCTAssertEqual(day.last?.date, d("2026-11-10 23:30")); let ints = day.filter { $0.id.contains("-i") }; XCTAssertTrue((5...6).contains(ints.count)); XCTAssertTrue(ints.allSatisfy { $0.date >= d("2026-11-10 11:00") && $0.date <= d("2026-11-10 23:00") }); XCTAssertTrue(zip(ints, ints.dropFirst()).allSatisfy { $1.date.timeIntervalSince($0.date) >= 75*60 }) }
func testWindowCoversSixDaysPlusReopen() { let p = run(); XCTAssertEqual(Set(p.filter { $0.id != "plan-reopen" }.map { logicalDay($0.date, calendar: cal) }).count, 6); XCTAssertEqual(p.last?.id, "plan-reopen"); XCTAssertEqual(p.last?.date, d("2026-11-16 10:00")); XCTAssertLessThanOrEqual(p.count, 60) }
func testDeterministic() { XCTAssertEqual(run(), run()) ; XCTAssertNotEqual(times(of: "2026-11-10"), times(of: "2026-11-11")) }  // times: kesintilerin gün içi dakikaları
func testPastItemsExcluded() { XCTAssertTrue(run(now: d("2026-11-10 15:00")).allSatisfy { $0.date > d("2026-11-10 15:00") }) }
func testNoDailyBeforeLoopStart() { state.loopStart = d("2026-11-12 00:00"); XCTAssertTrue(run().allSatisfy { $0.date >= d("2026-11-12 00:00") }) }
func testSetupDaySkipsPastTimes() { state.profile = nil; state.loopStart = nil; state.setupDate = d("2026-11-10 00:00"); let p = run(now: d("2026-11-10 14:00")); XCTAssertEqual(p.map(\.nodeId), ["synthesis"]); XCTAssertEqual(p.first?.date, d("2026-11-10 22:00")) }
func testSkipsInterruptWithEmptyVar() { state.profile!.enemy = ""; XCTAssertFalse(run().contains { $0.nodeId == "i3" }) }
func testChainUntilDelaysInterrupts() { let first = items(on: "2026-11-10").first { $0.id.hasSuffix("-i0") }!; state.chainUntil = first.date.addingTimeInterval(600); let moved = run(now: first.date.addingTimeInterval(-300)).first { $0.id == first.id }!; XCTAssertGreaterThanOrEqual(moved.date, state.chainUntil!) }
func testHarvestSent() { let prev = [PlannedItem(id: "a", date: d("2026-11-10 10:00"), nodeId: "morning", text: "", questIndex: nil), PlannedItem(id: "b", date: d("2026-11-10 11:30"), nodeId: "i1", text: "", questIndex: nil)]; let e = harvestSent(previous: prev, now: d("2026-11-10 11:00")); XCTAssertEqual(e.map(\.itemId), ["a"]); XCTAssertEqual(e.first?.kind, .sent) }
```
(`run(now:)`, `items(on:)`, `times(of:)`: `plan(now:state:content: fixture(), calendar: cal)` üzerinde test içi yardımcılar.)

- [ ] **Step 2:** `swift test --filter PlannerTests` → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat: bildirim planlayıcı`.

---

### Task 6: Senaryo motoru

**Files:**
- Create: `Sources/FYLCore/Engine.swift`, `Tests/FYLCoreTests/EngineTests.swift`

**Interfaces:**
- Consumes: `Content`, `render`, `AppState`, `Event`, `questStatus`.
- Produces:

```swift
public struct Reply: Equatable { public var itemId: String; public var nodeId: String; public var buttonIndex: Int; public var text: String?; public var questIndex: Int?; public var depth: Int }   // depth: kök = 1
public struct FollowUp: Equatable { public var nodeId: String; public var text: String; public var questIndex: Int?; public var depth: Int }
public func handle(_ reply: Reply, at now: Date, content: Content, state: inout AppState, rng: inout some RandomNumberGenerator) -> FollowUp?
```

Kurallar: Bilinmeyen düğüm ya da buton → hiçbir şey kaydetme, `nil`. Aksi hâlde `Event(.answered, nodeId, tag, text, questIndex, itemId)` ekle. Sonra sıradaki adım:
- `perQuest` düğümünde, `questIndex+1 < quests.count` ise aynı düğüm `questIndex+1` ile gelir, `depth` artmaz. Görevler bitince `after` düğümüne geçilir.
- Diğer düğümlerde buton `next`'i takip edilir, `depth+1` ile ve yalnızca `depth < 3` ise.
- Hedefin render edilebilir varyantı yoksa → `nil`.

FollowUp üretilirse `state.chainUntil = now + 20 dk` olur.

- [ ] **Step 1: Failing tests** (`state.profile = profile`, `rng = SplitMix64(seed: 1)`):

```swift
func testRecordsAnswerTag() { XCTAssertNil(h("i1", 1)); XCTAssertEqual(state.events.last?.tag, "istedigim_hayat"); XCTAssertEqual(state.events.last?.itemId, "it") }
func testFollowUpChain() { XCTAssertEqual(h("i1", 0)?.nodeId, "f1"); let f2 = h("f1", 0, depth: 2); XCTAssertEqual(f2, FollowUp(nodeId: "f2", text: "Yaratıcı biri ne yapardı?", questIndex: nil, depth: 3)); XCTAssertEqual(state.chainUntil, now.addingTimeInterval(1200)) }
func testDepthLimit() { XCTAssertNil(h("f1", 0, depth: 3)) }
func testPerQuestWalksQuestsThenRating() { XCTAssertEqual(h("quest_check", 0, q: 0), FollowUp(nodeId: "quest_check", text: "Görev: Yaz", questIndex: 1, depth: 1)); XCTAssertEqual(h("quest_check", 2, q: 1)?.nodeId, "day_rating") }
func testQuestStatusAcrossMidnight() { _ = h("quest_check", 0, q: 0, at: d("2026-11-10 23:40")); _ = h("quest_check", 2, q: 1, at: d("2026-11-11 00:10")); XCTAssertEqual(questStatus(state, on: d("2026-11-10 00:00"), calendar: cal), ["yaptim", "yapmadim"]) }
func testTextInputStored() { _ = h("i2", 0, text: "kahve"); XCTAssertEqual(state.events.last?.text, "kahve") }
func testUnknownNodeOrButtonIgnored() { XCTAssertNil(h("gone", 0)); XCTAssertNil(h("i1", 9)); XCTAssertTrue(state.events.isEmpty) }
```
(`h(node, button, depth: 1, q: nil, text: nil, at: now)`: `Reply(itemId: "it", …)` ile `handle` çağıran yardımcı.)

- [ ] **Step 2:** `swift test --filter EngineTests` → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat: senaryo motoru`.

---

### Task 7: Bildirim köprüsü

**Files:**
- Create: `App/Notifications.swift`
- Modify: `App/FixYourLifeApp.swift`

**Interfaces:**
- Consumes: `Content.load`, `plan`, `harvestSent`, `handle`, `Store`, `SplitMix64`.
- Produces:

```swift
@MainActor final class AppModel: ObservableObject {   // FixYourLifeApp.swift
    @Published var state: AppState; let content: Content     // content: Bundle.main "system.json"; Task 3 testi geçerliliği garanti eder, yüklenemezse fatalError
    func save()                 // Store.save → Application Support/state.json
    func replan()               // harvestSent(lastPlan) → events; plan() → Notifier.apply; lastPlan = yeni plan; save()
}
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    func registerCategories(_ content: Content)   // her düğüm = 1 kategori (id = düğüm id). Aksiyon id'si = buton indeksi ("0"…). input → UNTextInputNotificationAction, foreground → .foreground. hiddenPreviewsBodyPlaceholder = content.placeholder
    func apply(_ items: [PlannedItem])            // id'si "plan-" ile başlayan bekleyenleri sil, hepsini UNCalendarNotificationTrigger ile ekle
    func send(_ f: FollowUp, itemId: String)      // id "fu-<UUID>", 3 sn sonra UNTimeIntervalNotificationTrigger
}
```

`userInfo` anahtarları: `itemId`, `nodeId`, `questIndex` (yoksa yok), `depth` (planlı = 1). Bildirim başlığı yok, gövde = `text`, `categoryIdentifier = nodeId`.

- [ ] **Step 1:** Delegate'i `App.init` içinde ata, `Notifier` güçlü referansla tutulsun.
  - `didReceive`: `UNNotificationDefaultActionIdentifier` (bildirime dokunma) → yalnızca uygulamayı aç. `UNNotificationDismissActionIdentifier` → yok say. Sayısal aksiyon → `Reply` kur, `handle` çağır, FollowUp varsa `send` ile gönder, ardından `replan()`. `completionHandler`'ı en sonda çağır.
  - `willPresent` → `[.banner, .sound]`.
- [ ] **Step 2:** Uygulama her öne geldiğinde (`scenePhase == .active`) `replan()` çağır.
- [ ] **Step 3: Geçici test kancası** (yalnızca bu task'ın doğrulaması için, sonraki task'ta kaldırılır): `profile == nil` ise ekranda "Test: örnek profil + 1 dk sonra kesinti" butonu olsun. Buton `Fixture`'daki örnek profile benzer sabit bir profil kurar ve `i` kökü bulunan bir kesintiyi 60 sn sonra gönderir.
- [ ] **Step 4:** `swift test` yeşil. Commit `feat: bildirim köprüsü`, `git tag build-2`, push.
- [ ] **Step 5: Cihazda doğrula** (kullanıcıyla):
  - (a) İzin istemi çıkıyor.
  - (b) Test butonuna bas, uygulamayı arka plana al. 1 dk sonra bildirim gelir, kilit ekranında "Sana bir sorum var" görünür (önizleme ayarı "Kilit Açıkken" iken).
  - (c) Bildirimi uzun bas, butonlar görünür. Takipli butona bas, uygulama açılmadan 3 sn içinde takip sorusu gelir.
  - (d) Metin girişli butonda klavye açılır.

  Bir adım tutmazsa `systematic-debugging` kullan.

---

### Task 8: Karşılama + kurulum günü ekranları

**Files:**
- Create: `App/SetupView.swift`
- Modify: `App/FixYourLifeApp.swift` (kök ekran yönlendirmesi, test kancasını sil)

**Interfaces:**
- Consumes: `AppModel`, `Content.protocolMorning`, `Profile`.
- Produces: `struct SetupView: View`. Kök ekran kuralı: `profile == nil || setupDate == logicalDay(now)` ise `SetupView`, değilse `BoardView` (Task 9).

Ekranlar (tek dosya, `TabView`/`NavigationStack` serbest):
1. **Karşılama** (yalnızca `setupDate == nil && profile == nil`):
   - Bildirim izni iste.
   - Kilit ekranı adımını anlat: "Ayarlar → Bildirimler → FixYourLife → Önizlemeleri Göster → Kilit Açıkken". Yanına `UIApplication.openNotificationSettingsURLString` açan bir buton koy.
   - Kurulum günü seçimi: `DatePicker`, yalnızca tarih, en erken yarın. Varsayılan metin: "Yarın sabah başla". Kaydedince `setupDate` atanır ve `replan()` çağrılır.
2. **Sabah protokolü:** `protocolMorning` sorularını tek tek göster. Her soruda "Kâğıda yazdım → devam" butonu ve isteğe bağlı not alanı olsun (`setupNotes["g.q"]`). En başta makalenin uyarısını göster: cevapları kâğıda yaz, yapay zekâya devretme. Son adım: kimlik cümlesi alanı ("Ben … tipte biriyim").
3. **Akşam sentezi:** Alanlar:
   - Neden takıldım (isteğe bağlı)
   - Düşman*
   - Anti-vizyon tek cümle*
   - Vizyon MVP tek cümle*
   - 1 yıl*
   - 1 ay projesi*
   - Görevler (1–3; en az 1*)
   - Kısıtlar (0–3)

   Kimlik sabah adımından gelir ve burada da düzenlenebilir.

   Zorunlu alan (*) boşken "Oyunu başlat" butonu pasif olur. Kaydedince: `profile` atanır, `monthStart = logicalDay(now)`, `loopStart = logicalDay(now) + 1 gün`, `setupDate = nil`, ardından `replan()`.
4. Ayarlardan "Protokolü yeniden başlat" (Task 9) aynı akışı çalıştırır. Eski profil, yeni sentez kaydedilene kadar korunur.

- [ ] **Step 1:** Ekranları yaz. Metinler Türkçe, karanlık modda okunaklı, sistem fontu.
- [ ] **Step 2:** `swift test` yeşil. Commit `feat: kurulum günü ekranları`, `git tag build-3`, push.
- [ ] **Step 3: Cihazda doğrula:** Kurulum gününü yarına ayarla. Sabah protokolünü sona kadar git. Zorunlu alan boşken buton pasif olmalı. Sentezi kaydedince ertesi gün 10:00'da sabah bildirimi beklenir (bunu Task 9'dan sonra gerçek kullanımda gözlemle).

---

### Task 9: Oyun tahtası + ayarlar

**Files:**
- Create: `App/BoardView.swift`

**Interfaces:**
- Consumes: `AppModel`, `questStatus`, `Settings`, `Event`.
- Produces: `struct BoardView: View`.

- [ ] **Step 1: Tahta** (spec §6.2): Tek ekranda şunlar olsun:
  - Kazanma koşulu (vizyon), Risk (anti-vizyon), Ana görev (1 yıl).
  - Boss: 1 ay projesi + "X gün kaldı" (`30 − gün farkı(monthStart, bugün)`, en az 0).
  - Bugünün görevleri (tikli).
  - Kurallar (kısıtlar), kimlik, düşman.

  Her alan dokununca düzenlenebilir ve kaydedince `replan()` çalışır. Görev tikleri üç durumludur: boş → yaptım → kısmen → yapmadım. Her dokunuş `Event(.answered, nodeId: "board", tag:, questIndex:)` ekler. Durum `questStatus` ile okunur.

  Bildirim izni kapalıysa en üstte uyarı bandı ve ayarlar butonu göster.
- [ ] **Step 2: Ayarlar** (aynı dosya, sheet):
  - Sabah ve akşam saati: `DatePicker` hourAndMinute; akşam sabahtan sonra olmak zorunda, değilse kaydetme.
  - "Protokolü yeniden başlat": tarih seç → `setupDate`.
  - İçerik sürümü (`content.version`) salt okunur gösterilir.

  Değişiklikte `replan()` çalışır.
- [ ] **Step 3:** `swift test` yeşil. Commit `feat: oyun tahtası ve ayarlar`, `git tag build-4`, push.
- [ ] **Step 4: Cihazda doğrula ve bir gün yaşa:**
  - Sabah bildirimi geliyor.
  - 5–6 kesinti, 11:00–23:00 arası.
  - 23:30'da görev zinciri geliyor ve gün değerlendirmesiyle bitiyor.
  - Tahtadaki tikler kapanış cevaplarını yansıtıyor.
  - Bir sonraki gün planı yeni saatlerle geliyor.

  Görülen sorunları `content/CHANGELOG.md`'ye değil bir "Plan 2 girdileri" notuna yaz.

---

## Self-review notları

- Spec kapsamı: §6.1 → Task 8 + 5 (kurulum planı). §6.2 → Task 9. §6.3 günlük satırlar → Task 5/7. Haftalık/aylık/yıllık satırlar → Plan 2. §6.4 → Task 3/6/7. §6.5, §6.6 ekranı, §6.7 → Plan 2 (ham veri Task 4/5/6'da kaydediliyor). §5 gizlilik → Task 3 placeholder, Task 7 kategori, Task 8 rehber. §7 içerik ayrımı → Task 3. Uzaktan güncelleme → Plan 2. §8 → Task 1/2. §9b.1 → Task 7. §9b.2 cevapsız tanımı: Plan 2'de `sent` + `answered` olaylarından hesaplanır. §9b.3 → Task 5/8. §9b.5 → Task 9 (30 gün). §9b.6 → Task 3 render + Task 8 zorunlu alanlar.
- Sessiz saatler ayrı bir ayar değil: sabah/akşam saatleri dışında planlı bildirim yok. Takipler yalnızca kullanıcı az önce dokunduğunda gelir.
