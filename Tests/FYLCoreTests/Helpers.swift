import Foundation

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return c
}()

func d(_ s: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Istanbul")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}
