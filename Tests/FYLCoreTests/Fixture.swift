import Foundation
@testable import FYLCore

let fixtureJSON = """
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
"""

let profile = Profile(identity: "Yaratıcı biri", antiVision: "Masa başında çürüyen", vision: "Kendi işini yapan",
                      enemy: "Onay ihtiyacı", yearGoal: "İlk ürün", monthProject: "Uygulamayı bitir", whyStuck: "",
                      quests: ["Oku", "Yaz"], constraints: ["Uyku"], monthStart: d("2026-11-10 00:00"))

func fixture() -> Content { try! JSONDecoder().decode(Content.self, from: Data(fixtureJSON.utf8)) }
