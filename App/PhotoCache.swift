import Foundation

struct CachedPhoto: Codable { let id, nodeId, photographer, profileURL: String }

/// Application Support/photos: `<id>.jpg` + `<id>.json` (düğüm ve atıf). Bildirim kurulumu yalnızca buradan okur, ağa çıkmaz.
final class PhotoCache {
    let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("photos")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private func jpg(_ id: String) -> URL { dir.appendingPathComponent("\(id).jpg") }
    private func json(_ id: String) -> URL { dir.appendingPathComponent("\(id).json") }

    /// Düğüm → fotoğraf id'leri (dosya adı sırası). Görseli eksik olanlar sayılmaz.
    func available() -> [String: [String]] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        var out: [String: [String]] = [:]
        for n in names.sorted() where n.hasSuffix(".json") {
            let id = String(n.dropLast(5))
            guard let m = meta(id), fileURL(id) != nil else { continue }
            out[m.nodeId, default: []].append(id)
        }
        return out
    }

    func fileURL(_ id: String) -> URL? { FileManager.default.fileExists(atPath: jpg(id).path) ? jpg(id) : nil }

    func meta(_ id: String) -> CachedPhoto? {
        (try? Data(contentsOf: json(id))).flatMap { try? JSONDecoder().decode(CachedPhoto.self, from: $0) }
    }

    func remove(_ ids: [String]) {
        for id in ids { try? FileManager.default.removeItem(at: jpg(id)); try? FileManager.default.removeItem(at: json(id)) }
    }

    func store(_ p: UnsplashPhoto, nodeId: String, client: UnsplashClient) async throws {
        try await client.download(p, to: jpg(p.id))
        let m = CachedPhoto(id: p.id, nodeId: nodeId, photographer: p.user.name, profileURL: p.user.links.html)
        try JSONEncoder().encode(m).write(to: json(p.id), options: .atomic)
    }
}
