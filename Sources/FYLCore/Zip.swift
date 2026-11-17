import Foundation

/// Merkezi dizinden adı eşleşen ilk girdinin açık baytları. Yöntem 0 ham, 8 `inflate(sıkıştırılmış, açık boyut)`.
/// ZIP değilse ya da bozuksa nil; her okuma sınır denetimli.
// ponytail: ZIP64 ve çok diskli arşiv yok; .xlsx için gerekmez
public func zipEntry(_ archive: Data, where match: (String) -> Bool, inflate: (Data, Int) -> Data?) -> Data? {
    let b = [UInt8](archive)
    func u(_ at: Int, _ n: Int) -> Int? {
        guard at >= 0, n <= b.count, at <= b.count - n else { return nil }
        return (0..<n).reduce(0) { $0 | Int(b[at + $1]) << (8 * $1) }
    }
    func bytes(_ at: Int, _ n: Int) -> ArraySlice<UInt8>? {
        guard at >= 0, n >= 0, n <= b.count, at <= b.count - n else { return nil }
        return b[at..<at + n]
    }
    guard b.count >= 22, let eocd = stride(from: b.count - 22, through: max(0, b.count - 22 - 65535), by: -1)
            .first(where: { u($0, 4) == 0x06054b50 }),
          let count = u(eocd + 10, 2), var p = u(eocd + 16, 4) else { return nil }
    for _ in 0..<count {
        guard u(p, 4) == 0x02014b50, let method = u(p + 10, 2), let size = u(p + 20, 4), let full = u(p + 24, 4),
              let nl = u(p + 28, 2), let el = u(p + 30, 2), let cl = u(p + 32, 2), let local = u(p + 42, 4),
              let nameBytes = bytes(p + 46, nl) else { return nil }
        p += 46 + nl + el + cl
        guard match(String(decoding: nameBytes, as: UTF8.self)) else { continue }
        guard u(local, 4) == 0x04034b50, let lnl = u(local + 26, 2), let lel = u(local + 28, 2),
              let raw = bytes(local + 30 + lnl + lel, size) else { return nil }
        switch method {
        case 0: return Data(raw)
        case 8: return inflate(Data(raw), full)
        default: return nil
        }
    }
    return nil
}
