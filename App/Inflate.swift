import Foundation
import Compression

/// ZIP yöntem 8 (ham deflate) → açık bayt. Apple'ın `COMPRESSION_ZLIB`'i başlıksız ham deflate'tir.
/// `size` dosyadan denetimsiz gelir: 50 MB üstü reddedilir (ayırmadan önce).
func inflateRaw(_ data: Data, size: Int) -> Data? {
    guard size >= 0, size <= 50 << 20 else { return nil }
    if size == 0 { return Data() }
    guard !data.isEmpty else { return nil }
    var out = Data(count: size)
    let n = out.withUnsafeMutableBytes { dst in
        data.withUnsafeBytes { src in
            compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, size,
                                      src.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
        }
    }
    return n == size ? out : nil
}
