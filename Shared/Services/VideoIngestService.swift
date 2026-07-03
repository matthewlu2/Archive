import Foundation
import Supabase

/// Outcome of ingesting a shared URL.
struct IngestResult: Sendable {
    let video: VideoItem
    let archiveName: String
    let createdNewArchive: Bool
}

enum IngestError: LocalizedError {
    case notSignedIn
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You need to be signed in to save videos."
        case .invalidURL: "That link doesn't look like a valid video URL."
        }
    }
}

/// Orchestrates the share -> categorize -> save pipeline:
/// detect platform -> fetch metadata -> keyword-categorize into an existing
/// or new archive -> insert the video row.
struct VideoIngestService {
    private let metadata = MetadataService()
    private let categorizer = Categorizer()
    private let archives = ArchiveRepository()

    func ingest(urlString: String) async throws -> IngestResult {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.hasPrefix("http") == true else {
            throw IngestError.invalidURL
        }
        return try await ingest(url: url)
    }

    func ingest(url: URL) async throws -> IngestResult {
        guard let userID = supabase.auth.currentUser?.id else {
            throw IngestError.notSignedIn
        }

        let platform = Platform.detect(from: url)
        let canonical = canonicalize(url: url, platform: platform)
        let meta = await metadata.fetchMetadata(for: url, platform: platform)
        let myArchives = try await archives.fetchMyArchives(ownerID: userID)

        let result = categorizer.categorize(
            title: meta.title,
            authorName: meta.authorName,
            platform: platform,
            archives: myArchives
        )

        let targetArchiveID: UUID
        let targetArchiveName: String
        var createdNew = false

        switch result {
        case .existing(let archiveID, let newKeywords):
            targetArchiveID = archiveID
            targetArchiveName = myArchives.first(where: { $0.id == archiveID })?.name ?? "Archive"
            // Grow the folder's keyword vocabulary so matching improves over time.
            if !newKeywords.isEmpty,
               let archive = myArchives.first(where: { $0.id == archiveID }) {
                let merged = Array(Set(archive.keywords).union(newKeywords)).sorted()
                try? await archives.updateArchive(id: archiveID, keywords: merged)
            }
        case .newArchive(let name, let keywords):
            let created = try await archives.createArchive(
                NewArchiveFolder(ownerID: userID, name: name, keywords: keywords)
            )
            targetArchiveID = created.id
            targetArchiveName = created.name
            createdNew = true
        }

        let video = try await archives.insertVideo(NewVideoItem(
            archiveID: targetArchiveID,
            ownerID: userID,
            platform: platform,
            sourceURL: url.absoluteString,
            canonicalURL: canonical,
            title: meta.title,
            authorName: meta.authorName,
            thumbnailURL: meta.thumbnailURL
        ))

        return IngestResult(
            video: video,
            archiveName: targetArchiveName,
            createdNewArchive: createdNew
        )
    }

    // MARK: - URL canonicalization

    /// Normalizes share URLs so the same video always dedupes:
    /// resolves youtu.be/shorts forms, strips tracking query params.
    func canonicalize(url: URL, platform: Platform) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.fragment = nil

        switch platform {
        case .youtube:
            let host = (components.host ?? "").lowercased()
            var videoID: String?
            if host.contains("youtu.be") {
                videoID = components.path.split(separator: "/").first.map(String.init)
            } else if components.path.hasPrefix("/shorts/") || components.path.hasPrefix("/embed/") {
                videoID = components.path.split(separator: "/").dropFirst().first.map(String.init)
            } else {
                videoID = components.queryItems?.first(where: { $0.name == "v" })?.value
            }
            if let videoID, !videoID.isEmpty {
                return "https://www.youtube.com/watch?v=\(videoID)"
            }
        case .instagram, .tiktok, .snapchat, .other:
            // Path identifies the content; query params are tracking noise.
            components.queryItems = nil
        }

        components.host = components.host?.lowercased()
        // Trailing-slash normalization so /reel/abc/ == /reel/abc
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path = String(components.path.dropLast())
        }
        return components.url?.absoluteString ?? url.absoluteString
    }
}
