import Foundation

struct UnsplashPhoto: Decodable {
    struct URLs: Decodable { let raw: String }
    struct Links: Decodable { let html: String }
    struct User: Decodable { let name: String; let links: Links }
    let id: String; let urls: URLs; let user: User
}

struct UnsplashClient {
    let key: String
    struct HTTPError: Error { let status: Int }

    private func get(_ url: URL, auth: Bool = true) async throws -> Data {
        var r = URLRequest(url: url, timeoutInterval: 20)
        if auth { r.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization"); r.setValue("v1", forHTTPHeaderField: "Accept-Version") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw HTTPError(status: code) }
        return d
    }

    func search(_ query: String, page: Int, perPage: Int = 30) async throws -> [UnsplashPhoto] {
        var c = URLComponents(string: "https://api.unsplash.com/search/photos")!
        c.queryItems = [.init(name: "query", value: query), .init(name: "page", value: String(page)),
                        .init(name: "per_page", value: String(perPage)), .init(name: "orientation", value: "portrait"),
                        .init(name: "content_filter", value: "high")]
        struct Result: Decodable { let results: [UnsplashPhoto] }
        return try JSONDecoder().decode(Result.self, from: try await get(c.url!)).results
    }

    /// Görsel CDN'i (images.unsplash.com) API kotasına sayılmaz; anahtar gönderilmez.
    func download(_ p: UnsplashPhoto, to url: URL) async throws {
        guard let u = URL(string: p.urls.raw + (p.urls.raw.contains("?") ? "&" : "?") + "w=1080&fm=jpg&q=80") else {
            throw HTTPError(status: 0)
        }
        try await get(u, auth: false).write(to: url, options: .atomic)
    }

    func validate() async -> Bool { (try? await search("light", page: 1, perPage: 1)) != nil }
}
