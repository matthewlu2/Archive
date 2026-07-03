import SwiftUI
import WebKit

/// Plays a saved video via the platform's web embed, with a fallback
/// button that deep-links to the original app/site.
struct VideoPlayerView: View {
    let video: VideoItem

    private var sourceURL: URL? {
        URL(string: video.canonicalURL ?? video.sourceURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let embedURL {
                EmbedWebView(url: embedURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Preview unavailable",
                    systemImage: "play.slash",
                    description: Text("This platform doesn't allow embedded playback. Open it in the app instead.")
                )
            }

            infoBar
        }
        .navigationTitle(video.title ?? "Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let sourceURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: sourceURL)
                }
            }
        }
    }

    private var infoBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = video.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }
            HStack {
                Label(video.authorName ?? video.platform.displayName,
                      systemImage: video.platform.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let sourceURL {
                    Link(destination: sourceURL) {
                        Label("Open in \(video.platform.displayName)", systemImage: "arrow.up.forward.app")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    /// Platform-specific embed URL; nil when embedding isn't supported.
    private var embedURL: URL? {
        guard let url = sourceURL else { return nil }
        switch video.platform {
        case .youtube:
            if let id = youtubeID(from: url) {
                return URL(string: "https://www.youtube.com/embed/\(id)?playsinline=1")
            }
            return url
        case .tiktok:
            // tiktok.com/@user/video/<id> -> embed player
            let parts = url.path.split(separator: "/")
            if let videoIndex = parts.firstIndex(of: "video"), videoIndex + 1 < parts.count {
                return URL(string: "https://www.tiktok.com/embed/v2/\(parts[videoIndex + 1])")
            }
            return url
        case .instagram:
            // instagram.com/reel/<code>/ -> /reel/<code>/embed
            let trimmedPath = url.path.hasSuffix("/") ? String(url.path.dropLast()) : url.path
            return URL(string: "https://www.instagram.com\(trimmedPath)/embed")
        case .snapchat, .other:
            return url
        }
    }

    private func youtubeID(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        if host.contains("youtu.be") {
            return url.path.split(separator: "/").first.map(String.init)
        }
        if url.path.hasPrefix("/shorts/") || url.path.hasPrefix("/embed/") {
            return url.path.split(separator: "/").dropFirst().first.map(String.init)
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value
    }
}

// MARK: - WKWebView wrapper

struct EmbedWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
