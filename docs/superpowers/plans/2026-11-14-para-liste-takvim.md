# Para, kurlar, alınacaklar, takvim — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FixYourLife'ı yansıtma sisteminden; harcama/gelir takibi, anlık kurlar, büyük alınacaklar listesi (öğle hatırlatması) ve takvim (gruplanmış bildirimler) uygulamasına dönüştürmek.

**Architecture:** Tüm saf mantık (modeller, aylık özet, kuruş biçimleme, kur ayrıştırma, takvim tekrarları, bildirim gruplama, hediye maddesi, CSV) `FYLCore`'da kalır ve Linux CI'da test edilir. `App/` yalnızca SwiftUI ekranları, `AppModel` (durum + kaydetme + yeniden planlama), `Notifier` (UNUserNotificationCenter köprüsü) ve kur indirmeyi içerir. Durum tek `state.json`; mevcut `Store` deseni korunur.

**Tech Stack:** Swift 6.1, SwiftUI (iOS 17), UserNotifications, BackgroundTasks, URLSession, XcodeGen (`project.yml`), GitHub Actions, Codemagic → TestFlight.

**Spec:** `docs/superpowers/specs/2026-11-13-para-liste-takvim-design.md`

## Global Constraints

- Dal: `plan-2-gorsel` üzerinde devam. Bilgisayarda Swift yok. Doğrulama push sonrası: `gh run list --branch plan-2-gorsel --limit 2` → `test` ve `ios-build` ikisi de `completed success`. Hata ayrıntısı: `gh run view <id> --log-failed`.
- **`ios-build` Task 1'den Task 6'nın sonuna kadar kırmızı kalabilir** (eski ekranlar silinip yenileri Task 6'da gelir). `test` her görevin sonunda yeşil olmalı.
- iOS 17.0. Yeni üçüncü taraf bağımlılık yok.
- Bundle ID `com.meliksahhd.fixyourlife`, ASC Apple ID 6833892471, `codemagic.yaml` değişmez. Görünen ad `FixYourLife` kalır.
- Arayüz tamamen Türkçe. Para biçimi `tr_TR`: binlik nokta, ondalık virgül, sonda " ₺" (`14.820 ₺`, `14.820,50 ₺`).
- Tutarlar **kuruş cinsinden `Int`** (`Kurus`). Hesapta `Double` yok (kurlar hariç, onlar yalnızca gösterilir).
- Testlerde takvim `Europe/Istanbul` (`Tests/FYLCoreTests/Helpers.swift` içindeki `cal`, `d("yyyy-MM-dd HH:mm")`).
- `state.json` ileride değişirse yeni alanlar isteğe bağlı (`?`) eklenir; aksi halde eski dosya "bozuk" sayılıp kenara alınır.
- Bildirim bütçesi: 1 liste hatırlatması (`wish-noon`) + en fazla 60 takvim bildirimi (`cal-…`). Toplam ≤ 64.
- Kur kaynağı `https://finans.truncgil.com/v4/today.json`. 2026-11-14 itibarıyla gerçek yanıt şu biçimde (sayılar JSON sayısı, `Change` yüzde):
  `{"Update_Date":"2026-11-14 14:34:01","USD":{"Buying":50.3596,"Type":"Currency","Selling":50.3716,"Change":0.22},"EUR":{"Buying":55.553,"Type":"Currency","Selling":55.5666,"Change":-0.24},"GRA":{"Selling":6280.54,"Type":"Gold","Name":"GRAMALTIN","Change":0.32,"Buying":6279.53}, …}`

## Review Focus

1. **Tutar yazımı:** kullanıcı `1.250,50`, `120,5`, `120` yazar; nokta binlik, virgül ondalıktır. `120.5` binlik grup kuralına uymaz → reddedilir (sessizce 1205 TL olmamalı). Test: Task 2, `testParseKurus`.
2. **İleri tarihli kayıt:** Ekleme sayfasında tarih ayın ilerisine alınırsa "bugüne kadar harcadın" o kaydı bugünden önce saymamalı. Test: Task 2, `testFutureEntryNotCountedYet`.
3. **Sabah sınavı:** saati 08:30 olan sınavın "bugün" bildirimi 09:00'da gelirse işe yaramaz. "O gün" bildirimi `min(bildirim saati, sınav saati − 60 dk)` anında gelir. Test: Task 4, `testTimedEventSameDayFiresBeforeEvent`.
4. **CSV'de noktalı virgül / tırnak / satır sonu içeren not** sütunları kaydırmamalı; Türkçe karakterler Excel'de bozulmamalı (UTF-8 BOM). Test: Task 2, `testCSVEscapingAndBOM`.
5. **Eksik kur alanı:** Truncgil yanıtında `GRA` yoksa ya da sayılar `"50,3635"` metni olarak gelirse ekran boş kalmamalı; bulunanlar gösterilir. Test: Task 3, `testMissingCodeSkipped`, `testStringNumbers`.

---

### Task 1: Eski sistemi sil, yeni modeller ve durum

**Files:**
- Delete: `content/` (tamamı), `Sources/FYLCore/{Content,Engine,Planner,Photos,Random}.swift`, `Tests/FYLCoreTests/{ContentTests,EngineTests,PlannerTests,PhotosTests,RandomTests,Fixture}.swift`, `App/{BoardView,SetupView,PhotoHeader,PhotoCache,Unsplash,Keychain}.swift`
- Create: `Sources/FYLCore/Models.swift`
- Modify: `Sources/FYLCore/State.swift` (yeniden yaz; `Store` gövdesi aynen kalır), `project.yml` (`content/system.json` kaynağını kaldır)
- Test: `Tests/FYLCoreTests/StateTests.swift` (yeniden yaz)

**Interfaces:**
- Produces (`Models.swift`, hepsi `public`, her struct için `public init` ve `id: UUID = UUID()` varsayılanı):
  - `typealias Kurus = Int`
  - `enum Flow: String, Codable { case expense, income }`
  - `struct Category: Codable, Equatable, Identifiable { var id: String; var name: String; var flow: Flow }`
    - `static let otherExpense = "diger"`, `static let otherIncome = "diger-gelir"`
    - `static let defaults: [Category]` — sırasıyla gider: `market` Market, `yemek` Yemek / kafe, `ulasim` Ulaşım, `fatura` Fatura, `kira` Kira, `giyim` Giyim, `eglence` Eğlence, `saglik` Sağlık, `egitim` Eğitim, `diger` Diğer; gelir: `maas` Maaş, `ek-gelir` Ek gelir, `diger-gelir` Diğer
  - `struct Entry: Codable, Equatable, Identifiable { var id: UUID; var date: Date; var flow: Flow; var amount: Kurus; var categoryId: String; var note: String }`
  - `struct Wish: Codable, Equatable, Identifiable { var id: UUID; var name: String; var estimate: Kurus?; var boughtAt: Date?; var paid: Kurus?; var giftKey: String? }`
  - `enum EventKind: String, Codable, CaseIterable { case birthday, special, exam, task, other }` + `var title: String` ("Doğum günü", "Özel gün", "Sınav", "Görev", "Diğer")
  - `struct CalEvent: Codable, Equatable, Identifiable { var id: UUID; var name: String; var kind: EventKind; var date: Date; var minute: Int?; var yearly: Bool; var leadDays: [Int]; var gift: Bool }` — `date` olayın günü (yıllıkta yalnızca ay/gün anlamlı), `minute` günün dakikası (yalnızca exam/task'ta dolu olabilir)
    - `static let leadOptions = [0, 1, 2, 3, 7, 14, 30]`
    - `static func defaultLeadDays(_ k: EventKind) -> [Int]` — birthday/special `[3, 0]`, exam/task `[7, 1, 0]`, other `[0]`
    - `static func defaultYearly(_ k: EventKind) -> Bool` — birthday/special `true`, diğerleri `false`
- Produces (`State.swift`):
  - `struct Settings: Codable, Equatable { var wishReminder = true; var wishMinute = 750; var calendarMinute = 540 }`
  - `struct AppState: Codable, Equatable { var categories = Category.defaults; var entries: [Entry] = []; var wishes: [Wish] = []; var events: [CalEvent] = []; var giftKeys: Set<String> = []; var settings = Settings() }`
  - `extension AppState`: `func category(_ id: String) -> Category?`, `@discardableResult mutating func addCategory(name: String, flow: Flow) -> Category` (id `UUID().uuidString`), `mutating func renameCategory(id: String, to name: String)`, `@discardableResult mutating func deleteCategory(id: String) -> Bool`
  - `Store.load(_:) -> AppState?`, `Store.save(_:to:)` (değişmez), yeni `Store.encode(_ s: AppState) throws -> Data` (dışa aktarma için, `.prettyPrinted, .sortedKeys`, ISO8601 tarih)
  - `logicalDay` ve `questStatus` silinir.

- [ ] **Step 1: Eski dosyaları sil, `project.yml`'den `- path: content/system.json` / `buildPhase: resources` girdisini kaldır**

- [ ] **Step 2: `StateTests.swift`'i yeniden yaz (failing)**

Korunacak testler (yeni `AppState` ile): `testRoundTrip` (bir `Entry`, bir `Wish`, bir `CalEvent` ve bir `giftKeys` elemanıyla), `testMissingFileGivesFresh`, `testCorruptFileIsPreserved`, `testUnreadableFileIsNotTreatedAsMissing`. Eklenecekler:

```swift
func testOldV020StateIsMovedAsideAndFresh() throws {   // 0.2.0 biçimi: profile/events/lastPlan
    let u = tmpURL()
    try Data(#"{"settings":{"morning":"10:00","evening":"23:30"},"events":[],"lastPlan":[]}"#.utf8).write(to: u)
    XCTAssertEqual(Store.load(u), AppState())
    let siblings = try FileManager.default.contentsOfDirectory(atPath: u.deletingLastPathComponent().path)
    XCTAssertTrue(siblings.contains { $0.hasPrefix("state-corrupt-") })
}
func testDeleteCategoryMovesEntriesToOther() {
    var s = AppState()
    s.entries = [Entry(date: d("2026-11-10 12:00"), flow: .expense, amount: 5000, categoryId: "kira", note: "")]
    XCTAssertTrue(s.deleteCategory(id: "kira"))
    XCTAssertNil(s.category("kira"))
    XCTAssertEqual(s.entries[0].categoryId, Category.otherExpense)
}
func testDeleteIncomeCategoryMovesToIncomeOther() { /* "maas" → "diger-gelir" */ }
func testOtherCannotBeDeleted() {
    var s = AppState()
    XCTAssertFalse(s.deleteCategory(id: "diger")); XCTAssertFalse(s.deleteCategory(id: "diger-gelir"))
    XCTAssertEqual(s.categories, Category.defaults)
}
func testRenameKeepsEntryLink() {
    var s = AppState(); s.renameCategory(id: "market", to: "Süpermarket")
    XCTAssertEqual(s.category("market")?.name, "Süpermarket")
}
func testDefaultCategories() {
    XCTAssertEqual(Category.defaults.filter { $0.flow == .expense }.count, 10)
    XCTAssertEqual(Category.defaults.filter { $0.flow == .income }.map(\.id), ["maas", "ek-gelir", "diger-gelir"])
}
```

- [ ] **Step 3: `Models.swift` ve yeni `State.swift`'i yaz**

- [ ] **Step 4: Push, `test` iş akışı yeşil** (`ios-build` kırmızı olabilir, beklenen)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor!: yansıtma sistemi kaldırıldı; para/liste/takvim modelleri ve durum"
```

---

### Task 2: Kuruş, aylık özet, CSV

**Files:**
- Create: `Sources/FYLCore/Money.swift`
- Test: `Tests/FYLCoreTests/MoneyTests.swift`

**Interfaces:**
- Consumes: Task 1 modelleri.
- Produces:
  - `func parseKurus(_ text: String) -> Kurus?` — baştaki/sondaki boşluk kırpılır. Virgül ondalık (en çok 2 hane), nokta yalnızca binlik ayırıcı (noktadan sonra tam 3 rakam). Boş, geçersiz, ≤ 0 → `nil`.
  - `func formatTL(_ k: Kurus) -> String` — kuruş 0 ise ondalık yok. Elle gruplama (Linux ICU farkına güvenme).
  - `struct CategoryTotal: Equatable { var categoryId: String; var amount: Kurus }`
  - `struct MonthSummary: Equatable { var spent, lastMonthToDate, lastMonthTotal, income: Kurus; var changePercent: Int?; var top: [CategoryTotal] }`
  - `func monthSummary(_ entries: [Entry], now: Date, calendar: Calendar) -> MonthSummary`
    - `spent`: bu ayın 1'i 00:00 ≤ tarih < yarın 00:00 olan giderler (ileri tarihli kayıt bugünden sonra sayılmaz).
    - `lastMonthToDate`: geçen ayın 1'i ≤ tarih < geçen ayın `min(bugünün günü, geçen ayın gün sayısı) + 1`. günü 00:00.
    - `lastMonthTotal`: geçen ayın tüm giderleri. `income`: `spent` ile aynı aralıktaki gelirler.
    - `changePercent`: `lastMonthToDate == 0` ise `nil`, yoksa `((spent − lmtd) * 100 / lmtd)` en yakın tamsayıya yuvarlanmış.
    - `top`: `spent` aralığındaki giderler kategoriye göre toplanır, tutara göre azalan; eşitlikte `categoryId` artan. Sıfırlar yok.
  - `func csv(_ state: AppState, calendar: Calendar) -> String` — `"\u{FEFF}"` + başlık `tarih;tür;kategori;tutar;not`, satırlar tarihe göre artan, `\n` ile. tarih `yyyy-MM-dd HH:mm` (`calendar.timeZone`), tür `Gider`/`Gelir`, kategori adı (bilinmeyen id → `Diğer`), tutar gruplamasız virgüllü (`120,50`, `5000,00`). Bir alan `;`, `"` ya da satır sonu içeriyorsa çift tırnağa alınır, içteki `"` → `""`.

- [ ] **Step 1: Failing testler**

```swift
func testParseKurus() {
    XCTAssertEqual(parseKurus("120"), 12000); XCTAssertEqual(parseKurus(" 120,5 "), 12050)
    XCTAssertEqual(parseKurus("1.250,50"), 125050); XCTAssertEqual(parseKurus("12.500"), 1250000)
    for bad in ["", "0", "-5", "abc", "1,234", "120.5", "1.25,00", "12,"] { XCTAssertNil(parseKurus(bad), bad) }
}
func testFormatTL() {
    XCTAssertEqual(formatTL(1482000), "14.820 ₺"); XCTAssertEqual(formatTL(1482050), "14.820,50 ₺")
    XCTAssertEqual(formatTL(0), "0 ₺"); XCTAssertEqual(formatTL(5), "0,05 ₺"); XCTAssertEqual(formatTL(123456789), "1.234.567,89 ₺")
}
func testSummarySameDayCutoff() {
    // now 2026-11-14 15:00. Ekim: 3'ü 100 ₺, 14'ü 23:59 50 ₺, 15'i 70 ₺. Kasım: 2'si 180 ₺ (market), 14'ü 10:00 30 ₺ (yemek), gelir 1'i 32.000 ₺.
    // spent 21000, lastMonthToDate 15000, lastMonthTotal 22000, income 3200000, changePercent 40, top [market 18000, yemek 3000]
}
func testSummaryCutoffAtShorterMonth() {   // now 2026-03-31: Şubat 28'i dahil, Şubat 2026'da 29 yok
}
func testSummaryJanuaryComparesWithDecember() { /* now 2027-01-10: 2026-12-05 kaydı lastMonthToDate'e girer */ }
func testNoChangePercentWhenLastMonthEmpty() { /* changePercent nil */ }
func testFutureEntryNotCountedYet() { /* now 2026-11-14 15:00; 2026-11-20 kaydı spent'e girmez */ }
func testTopTieBreakById() { /* iki kategori eşit tutar → id sırası */ }
func testCSVEscapingAndBOM() {
    var s = AppState()
    s.entries = [Entry(date: d("2026-11-14 09:05"), flow: .expense, amount: 12050, categoryId: "market", note: "süt; \"tam\" yağlı"),
                 Entry(date: d("2026-11-01 08:00"), flow: .income, amount: 3200000, categoryId: "maas", note: "")]
    XCTAssertEqual(csv(s, calendar: cal),
        "\u{FEFF}tarih;tür;kategori;tutar;not\n2026-11-01 08:00;Gelir;Maaş;32000,00;\n2026-11-14 09:05;Gider;Market;120,50;\"süt; \"\"tam\"\" yağlı\"")
}
```

Yorumla verilen testlerde değerler yorumdaki gibi; `Entry` kurmak için dosyada küçük bir `func e(_ date: String, _ tl: Int, _ cat: String = "market", _ flow: Flow = .expense) -> Entry` yardımcısı yaz.

- [ ] **Step 2: Push, testler kırmızı (derleme hatası: `parseKurus` yok)**
- [ ] **Step 3: `Money.swift`'i yaz**
- [ ] **Step 4: Push, `test` yeşil**
- [ ] **Step 5: Commit** — `feat(core): kuruş ayrıştırma/biçimleme, aylık özet, CSV`

---

### Task 3: Kur ayrıştırma

**Files:**
- Create: `Sources/FYLCore/Rates.swift`
- Test: `Tests/FYLCoreTests/RatesTests.swift` (gerçek yanıt Global Constraints'teki satırdan dize olarak gömülür; paket kaynağı eklenmez)

**Interfaces:**
- Produces:
  - `struct Rate: Equatable { var code: String; var selling: Double; var changePercent: Double }`
  - `struct RatesSnapshot: Equatable { var updated: Date?; var rates: [Rate] }`
  - `func parseRates(_ data: Data) -> RatesSnapshot?` — `JSONSerialization`. Sıra her zaman `USD, EUR, GRA`; bulunmayan kod atlanır. Sayı ya da `"50,3635"`/`"%0,22"` metni kabul edilir (`%` atılır, virgül → nokta). `Update_Date` `yyyy-MM-dd HH:mm:ss`, `Europe/Istanbul`, `en_US_POSIX`. JSON geçersizse ya da üç koddan hiçbiri yoksa `nil`.
  - `func formatRate(_ v: Double) -> String` — 2 ondalık, tr gruplama: `50,37`, `6.280,54`
  - `func formatChange(_ p: Double) -> String` — `+%0,22`, `-%0,24`, `%0,00`

- [ ] **Step 1: Failing testler** — `testParsesRealResponse` (3 kur, USD selling 50.3716, EUR change -0.24, `updated == d("2026-11-14 14:34")` + 1 sn), `testStringNumbers` (`{"USD":{"Selling":"50,3635","Change":"%0,22"}}` → 50.3635 / 0.22), `testMissingCodeSkipped` (yalnızca USD ve EUR → 2 kur, sıra korunur), `testGarbageIsNil` (`"<html>"` ve `{}` → nil), `testFormatRate`, `testFormatChange`.
- [ ] **Step 2: Push, kırmızı**
- [ ] **Step 3: `Rates.swift`'i yaz.** Yedek kaynak yok: `// ponytail: tek kaynak Truncgil; çökerse TCMB today.xml (USD/EUR, altın yok) yedek olarak eklenir` yorumunu `parseRates` üstüne koy.
- [ ] **Step 4: Push, yeşil**
- [ ] **Step 5: Commit** — `feat(core): Truncgil kur ayrıştırma`

---

### Task 4: Takvim tekrarları ve gruplanmış hatırlatmalar

**Files:**
- Create: `Sources/FYLCore/Reminders.swift`
- Test: `Tests/FYLCoreTests/RemindersTests.swift`

**Interfaces:**
- Consumes: `CalEvent`, `EventKind` (Task 1).
- Produces:
  - `func nextOccurrence(_ e: CalEvent, from day: Date, calendar: Calendar) -> Date?` — `day`ın gün başından itibaren ilk gerçekleşmenin gün başı. Yıllık: o yılın ay/günü, geçtiyse sonraki yıl; 29 Şubat artık olmayan yılda 28 Şubat. Bir kerelik: `date` günü ≥ `day` ise o, değilse `nil`.
  - `func daysUntil(_ e: CalEvent, now: Date, calendar: Calendar) -> Int?` — bugünden sonraki gerçekleşmeye gün farkı (bugün = 0).
  - `func countdownText(_ days: Int) -> String` — `0` "bugün", `1` "yarın", `n` "\(n) gün kaldı"
  - `struct Reminder: Equatable { var fireAt: Date; var lines: [String] }`
  - `func reminders(_ events: [CalEvent], now: Date, minuteOfDay: Int, calendar: Calendar, limit: Int = 60) -> [Reminder]`

Algoritma (`reminders`):
1. Her olay için gerçekleşmeler: yıllıkta bugünden itibaren ilk iki (`n` ve `n+1`. yıl), bir kerelikte en fazla bir. `// ponytail: yıllık olay için 2 gerçekleşme; uygulama her açılışta yeniden planladığı için yeter`
2. Her gerçekleşme × `leadDays` için ateşleme anı: `gerçekleşme − lead gün`, saat `minuteOfDay`. İstisna: `lead == 0` ve `minute != nil` ise `min(minuteOfDay, minute − 60)` (0'ın altına inmez).
3. `fireAt <= now` olanlar atılır. Aynı `fireAt` olanlar tek `Reminder`da birleşir; satırlar `lead` artan, sonra ad artan.
4. `fireAt` artan sırala, `prefix(limit)`.

Satır: `"<önek>: <ad><emoji><hediye>"`.
- önek: lead 0 "Bugün", 1 "Yarın", n "\(n) gün sonra"; `minute` doluysa sonuna " HH:mm" (ör. "Bugün 14:00").
- emoji: birthday " 🎂", special " ✨", exam " 📝", diğerleri yok.
- hediye: `gift && lead >= 1` ise " · Hediye almayı unutma".

- [ ] **Step 1: Failing testler**

```swift
func testYearlyNextOccurrenceRollsOver() { /* 5 Mart doğum günü, from 2026-11-14 → 2027-03-05 00:00 */ }
func testLeapDayBirthday() { /* 29 Şubat 2024 doğumlu, from 2026-11-14 → 2027-02-28; from 2027-03-01 → 2028-02-29 */ }
func testOneOffPastIsNil() { /* sınav 2026-11-01, from 2026-11-14 → nil; aynı gün → o gün */ }
func testCountdown() { XCTAssertEqual(countdownText(0), "bugün"); XCTAssertEqual(countdownText(1), "yarın"); XCTAssertEqual(countdownText(3), "3 gün kaldı") }
func testGroupsSameMomentIntoOneReminder() {
    // now 2026-11-14 08:00, minuteOfDay 540. "Annemin doğum günü" 2026-11-17 birthday [3,0] gift; "Matematik sınavı" 2026-11-15 exam [1,0] minute nil
    // İlk Reminder: fireAt 2026-11-14 09:00, lines ["Yarın: Matematik sınavı 📝", "3 gün sonra: Annemin doğum günü 🎂 · Hediye almayı unutma"]
}
func testTimedEventSameDayFiresBeforeEvent() {
    // sınav 2026-11-20 minute 510 (08:30), leadDays [0], minuteOfDay 540 → fireAt 2026-11-20 07:30, line "Bugün 08:30: … 📝"
}
func testPastFiresDropped() { /* now 2026-11-14 10:00, bugünkü 09:00 bildirimi yok */ }
func testLimit() { /* 40 bir kerelik olay, 10 gün arayla, her biri [7,1,0] → reminders(...).count == 60, fireAt artan */ }
func testYearlyHasTwoOccurrences() { /* tek doğum günü [0] → 2 Reminder, bir yıl arayla */ }
```

- [ ] **Step 2: Push, kırmızı**
- [ ] **Step 3: `Reminders.swift`'i yaz**
- [ ] **Step 4: Push, yeşil**
- [ ] **Step 5: Commit** — `feat(core): takvim tekrarları ve gruplanmış hatırlatmalar`

---

### Task 5: Alınacaklar ve hediye maddesi

**Files:**
- Create: `Sources/FYLCore/Wishes.swift`
- Test: `Tests/FYLCoreTests/WishesTests.swift`

**Interfaces:**
- Consumes: `Wish`, `Entry`, `AppState`, `Category.otherExpense` (Task 1); `nextOccurrence` / `daysUntil` (Task 4).
- Produces:
  - `func pendingTotal(_ wishes: [Wish]) -> Kurus` — `boughtAt == nil` ve `estimate != nil` olanların toplamı.
  - `func noonBody(_ wishes: [Wish]) -> String?` — bekleyenler eklenme sırasıyla: `"Bugün alabilirsin: a, b, c"`; 3'ten fazlaysa `"Bugün alabilirsin: a, b, c +2"`. Bekleyen yoksa `nil`.
  - `extension AppState { mutating func buy(_ id: UUID, paid: Kurus?, categoryId: String = Category.otherExpense, at date: Date) }` — `boughtAt = date`, `paid = paid`; `paid != nil` ise `entries`'e `Entry(date: date, flow: .expense, amount: paid, categoryId: categoryId, note: wish.name)` eklenir.
  - `extension AppState { mutating func addGiftWishes(now: Date, calendar: Calendar) }` — `gift == true` ve tür birthday/special olup `daysUntil` 0...3 olan her olay için anahtar `"\(e.id.uuidString)-\(gerçekleşme yılı)"`. Anahtar `giftKeys`'te yoksa `Wish(name: "🎁 \(e.name) için hediye", giftKey: anahtar)` eklenir ve anahtar `giftKeys`'e girer. Madde silinse de anahtar kalır.

- [ ] **Step 1: Failing testler** — `testPendingTotalIgnoresBoughtAndUnpriced`, `testNoonBody` (`nil` boşken; 2 madde `"Bugün alabilirsin: bilgisayar çantası, kulaklık"`; 5 madde `"… a, b, c +2"`; alınanlar sayılmaz), `testBuyCreatesExpense` (paid 85000 → `Entry` not "bilgisayar çantası", kategori "diger"), `testBuyWithoutAmountCreatesNoEntry`, `testGiftAddedOnceWithinThreeDays` (now 2026-11-14, doğum günü 17 Kasım → eklenir; ikinci çağrı eklemez; madde silinip yeniden çağrılınca eklenmez; 18 Kasım doğum günü → eklenmez; `gift == false` → eklenmez), `testGiftNextYearAddsAgain` (2027-11-14'te aynı olay için yeni anahtar → yeniden eklenir).
- [ ] **Step 2: Push, kırmızı**
- [ ] **Step 3: `Wishes.swift`'i yaz**
- [ ] **Step 4: Push, yeşil**
- [ ] **Step 5: Commit** — `feat(core): alınacaklar, öğle metni, hediye maddesi`

---

### Task 6: Uygulama çekirdeği, bildirimler, Özet ve Hareketler

**Files:**
- Modify: `App/FixYourLifeApp.swift` (yeniden yaz), `App/Notifications.swift` (yeniden yaz), `App/Theme.swift`, `project.yml`
- Create: `App/SummaryView.swift`, `App/EntriesView.swift` (liste + `EntryForm`)
- Test: yok (iOS); doğrulama `ios-build`

**Interfaces:**
- Consumes: Task 1–5'in tamamı.
- Produces (`AppModel`, `@MainActor final class: ObservableObject`, `static let shared`):
  - `@Published var state: AppState`, `@Published var rates: RatesSnapshot?`, `@Published var ratesFailed = false`, `@Published var tab: AppTab` (`enum AppTab: Hashable { case summary, entries, wishes, calendar }`)
  - `func update(_ change: (inout AppState) -> Void)` — yüklenmemişse (`loaded_ == false`) hiçbir şey yapmaz; değiştirir, `save()`, `reschedule()`.
  - `func reschedule()` — `state.addGiftWishes(now:calendar:)` + `save()`; sonra `notifier.apply(reminders: reminders(state.events, now: Date(), minuteOfDay: state.settings.calendarMinute, calendar: .current), noon: state.settings.wishReminder ? noonBody(state.wishes) : nil, noonMinute: state.settings.wishMinute)`. Çağrılar mevcut `applying` zinciriyle sıralanır.
  - `func refreshRates() async` — `URLSession.shared.data(from:)`, `parseRates`; başarıda `rates` güncellenir, ham veri `Application Support/rates.json`'a yazılır, `ratesFailed = false`; hatada `ratesFailed = true`, eski değer kalır. `init`'te `rates.json` varsa ondan yüklenir.
  - `static let refreshTaskId = "com.meliksahhd.fixyourlife.refresh"`, `func scheduleRefresh()` (12 saat sonra `BGAppRefreshTaskRequest`).
- Produces (`Notifier`): `func apply(reminders: [Reminder], noon: String?, noonMinute: Int) async` — `removeAllPendingNotificationRequests()` ile **tüm** bekleyenleri siler (0.2.0'dan kalan `plan-`/`fu-` soru bildirimleri de gitsin; bütün bildirimler bu uygulamanın) ve `setNotificationCategories([])` çağırır. Her `Reminder` için id `cal-yyyyMMddHHmm`, başlık "Takvim", gövde `lines.joined(separator: "\n")`, `userInfo["tab"] = "calendar"`, tekrarsız takvim tetikleyici. `noon != nil` ise id `wish-noon`, başlık "Alınacaklar", gövde `noon`, `userInfo["tab"] = "wishes"`, `UNCalendarNotificationTrigger(dateMatching: saat+dakika, repeats: true)`. Dokununca `didReceive` → `model.tab` ilgili sekme.
- Produces (`Theme`): `up = Color(hex: 0x4CAF7A)` (kur artışı, geçen aydan az harcama, gelir), `down = accent` (`0xE5534B`), `tint = Color(hex: 0xC9A66B)` (nötr vurgu, `.tint` olarak). `riskCard` silinir.

Akış:
- `init`: `Store.load`; `nil` ise `loaded_ = false` (mevcut davranış, kaydetme yok). `UNUserNotificationCenter.current().delegate = notifier`.
- Sahne `.active`: yeniden yükleme denemesi, bildirim izni iste (`.alert, .sound, .badge`, ilk açılışta sistem sorar), `reschedule()`, `Task { await refreshRates() }`. `.background`: `save()`, `scheduleRefresh()`.
- `.backgroundTask(.appRefresh(refreshTaskId))`: `scheduleRefresh()`, `reschedule()`, `await applying?.value` (iOS askıya almadan bildirimler kurulmuş olsun).
- Kök: `TabView(selection: $model.tab)` — Özet (`chart.pie`), Hareketler (`list.bullet`). Alınacaklar (`bag`) ve Takvim (`calendar`) sekmelerini Task 7 ekler; bu görevde yer tutucu yazma.

Ekranlar (spec §6.1'deki metin ve düzen aynen):
- `SummaryView`: `NavigationStack`, başlık "Özet", sağ üst dişli → `SettingsView` (Task 7; bu görevde dişliyi koyma). Üç kur kartı (Dolar/Euro/Gram altın; `formatRate`, `formatChange`, `up`/`down` renk; kur yoksa "—"), altında "Güncelleme HH:mm" (`ratesFailed` iken `opacity(0.5)`), `.refreshable { await refreshRates() }`. Harcama kartı ("Kasım · bugüne kadar harcadın", `formatTL(spent)`; "Geçen ay aynı güne kadar X · %N fazla/az" — fazla `down`, az `up`, `changePercent == nil` ise yüzde kısmı yok; "Geçen ayın tamamı X · Gelir bu ay Y"). "En çok nereye" kartı: `top`, her satırda ad, tutar ve en büyüğe göre oranlı yatay çubuk. Altta `PrimaryButtonStyle` "+ Harcama / gelir ekle" → `EntryForm` sayfası.
- `EntryForm(entry: Entry?)`: Gider/Gelir `Picker(.segmented)`, tutar `TextField` + `.keyboardType(.decimalPad)` + `@FocusState` otomatik odak, kategori yatay kaydırılan çipler (seçili akışın kategorileri), not, `DatePicker` (varsayılan şimdi). Kaydet `parseKurus` `nil` ise pasif. Yeni kayıt ekler, mevcut olanı yerinde günceller.
- `EntriesView`: `List`, aylara göre `Section` (başlık "Kasım 2026", `tr_TR`), yeniden eskiye. Satır: kategori adı, not (ikincil), tutar (gelir `up` renkli ve "+" önekli). Dokun → `EntryForm(entry:)`, sola kaydır → sil.

`project.yml`: `BGTaskSchedulerPermittedIdentifiers: [com.meliksahhd.fixyourlife.refresh]`, `MARKETING_VERSION: 0.3.0`.

- [ ] **Step 1: `Theme.swift`, `project.yml`, `Notifications.swift`, `FixYourLifeApp.swift`'i yaz**
- [ ] **Step 2: `SummaryView.swift`, `EntriesView.swift`'i yaz**
- [ ] **Step 3: Push, `test` ve `ios-build` yeşil** (ilk kez ikisi birden)
- [ ] **Step 4: Commit** — `feat(app): uygulama çekirdeği, bildirimler, Özet ve Hareketler`

---

### Task 7: Alınacaklar, Takvim ve Ayarlar ekranları

**Files:**
- Create: `App/WishesView.swift`, `App/CalendarView.swift` (liste + `EventForm`), `App/SettingsView.swift`
- Modify: `App/FixYourLifeApp.swift` (iki sekmeyi ekle), `App/SummaryView.swift` (dişli)

**Interfaces:**
- Consumes: `AppModel.update`, Task 1–5 fonksiyonları.

Ekranlar (spec §6.3–6.5):
- `WishesView`: üstte "Bekleyen ≈ `formatTL(pendingTotal)`" (toplam 0 ise yok). Bekleyenler: ad + tahmini fiyat; dokun → düzenle (ad, tahmini fiyat), kaydır → sil, sağda "Aldım" düğmesi → sayfa: ödenen tutar (tahminle önceden dolu, boş bırakılabilir), gider kategorisi çipleri (varsayılan Diğer), Kaydet → `state.buy(...)`. "Alındı" bölümü `DisclosureGroup`, varsayılan kapalı, satırda ödenen tutar ve tarih. Sağ üst "+" → yeni madde.
- `CalendarView`: gelecek olaylar `daysUntil` artan, satırda ad, tür, `countdownText`; geçmiş bir kerelikler alttaki "Geçmiş" bölümünde. Dokun → `EventForm(event:)`, kaydır → sil. "+" → yeni.
- `EventForm`: ad (yer tutucu "Örn. Annemin doğum günü"), tür `Picker` (tür değişince `leadDays` ve `yearly` varsayılana döner), tarih, saat anahtarı + saat (yalnızca exam/task), "Her yıl" anahtarı (yalnızca other), hatırlatma günleri `leadOptions` üzerinden çoklu seçim (0 → "O gün", n → "\(n) gün önce"), "Hediye al" anahtarı (yalnızca birthday/special). Hatırlatma seçimi boş bırakılamaz (Kaydet pasif).
- `SettingsView` (`Form`, `themedForm()`): liste hatırlatması aç/kapat + saat; takvim bildirim saati (`DatePicker(.hourAndMinute)` ↔ dakika-gün); kategoriler (gider/gelir bölümleri, ekle, yeniden adlandır, kaydırarak sil; Diğer'de silme yok); dışa aktarma: `ShareLink` ile `csv(state, calendar: .current)` geçici `hareketler.csv` dosyası ve `Store.encode(state)` geçici `fixyourlife-yedek.json` dosyası.

- [ ] **Step 1: Üç ekranı yaz, sekmeleri ve dişliyi bağla**
- [ ] **Step 2: Push, iki iş akışı yeşil**
- [ ] **Step 3: Commit** — `feat(app): Alınacaklar, Takvim ve Ayarlar`

---

### Task 8: Belgeler ve sürüm

**Files:**
- Modify: `CLAUDE.md` (yeni amaç, durum; "Makale ekleme akışı" kaldırılır), `docs/kurulum.md` (Unsplash ve kurulum günü bölümleri kaldırılır; Apple/Codemagic adımları kalır)

- [ ] **Step 1: İki belgeyi güncelle, commit** — `docs: para/liste/takvim dönüşümü`
- [ ] **Step 2: Kullanıcıya sor, onay gelirse** `git tag build-3 && git push origin plan-2-gorsel build-3` (Codemagic kotası harcar)
- [ ] **Step 3: Codemagic derlemesi bitince TestFlight'ta 0.3.0'ın göründüğünü doğrula** ve kullanıcıya cihaz kontrol listesini ver: ilk açılışta bildirim izni; bir harcama ekle → Özet'te görünür; kurlar dolu; yarına bir olay ekle → ertesi gün 09:00 bildirimi; bir madde ekle → 12:30 bildirimi; Ayarlar → dışa aktarılan CSV Excel'de düzgün açılır.
