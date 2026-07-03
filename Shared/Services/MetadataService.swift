import Foundation

/// Metadata extracted for a shared video URL.
struct VideoMetadata: Sendable {
    var title: String?
    var authorName: String?
    var thumbnailURL: String?

    static let empty = VideoMetadata()
}

/// Fetches title/author/thumbnail for a video URL.
///
/// YouTube and TikTok expose public oEmbed endpoints; Instagram/Snapchat
/// (and anything else) fall back to best-effort OpenGraph scraping. Every
/// path degrades to `.empty` — ingest never fails because metadata did.
struct MetadataService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchMetadata(for url: URL, platform: Platform) async -> VideoMetadata {
        switch platform {
        case .youtube:
            if let meta = await fetchOEmbed(endpoint: "https://www.youtube.com/oembed", videoURL: url) {
                return meta
            }
        case .tiktok:
            if let meta = await fetchOEmbed(endpoint: "https://www.tiktok.com/oembed", videoURL: url) {
                return meta
            }
        case .instagram, .snapchat, .other:
            break
        }
        // Fallback for everything: OpenGraph scrape.
        return await fetchOpenGraph(url: url) ?? .empty
    }

    // MARK: - oEmbed

    private struct OEmbedResponse: Decodable {
        let title: String?
        let authorName: String?
        let thumbnailUrl: String?

        enum CodingKeys: String, CodingKey {
            case title
            case authorName = "author_name"
            case thumbnailUrl = "thumbnail_url"
        }
    }

    private func fetchOEmbed(endpoint: String, videoURL: URL) async -> VideoMetadata? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [URLQueryItem(name: "url", value: videoURL.absoluteString)]
        guard let requestURL = components?.url else { return nil }

        do {
            let (data, response) = try await session.data(from: requestURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let oembed = try JSONDecoder().decode(OEmbedResponse.self, from: data)
            return VideoMetadata(
                title: oembed.title,
                authorName: oembed.authorName,
                thumbnailURL: oembed.thumbnailUrl
            )
        } catch {
            return nil
        }
    }

    // MARK: - OpenGraph

    private func fetchOpenGraph(url: URL) async -> VideoMetadata? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Some platforms serve richer OG tags to link-preview bots.
        request.setValue("facebookexternalhit/1.1", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        let title = ogContent(in: html, property: "og:title")
        let image = ogContent(in: html, property: "og:image")
        var meta = VideoMetadata(title: title, authorName: nil, thumbnailURL: image)
        if meta.title == nil, let range = html.range(of: "<title>"),
           let end = html.range(of: "</title>", range: range.upperBound..<html.endIndex) {
            meta.title = String(html[range.upperBound..<end.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if meta.title == nil && meta.thumbnailURL == nil { return nil }
        return meta
    }

    /// Extracts `content` from an OpenGraph meta tag, tolerating attribute order.
    private func ogContent(in html: String, property: String) -> String? {
        let patterns = [
            "<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+property=[\"']\(property)[\"']",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                let value = String(html[range])
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                if !value.isEmpty { return value }
            }
        }
        return nil
    }
}
