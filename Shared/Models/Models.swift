import Foundation

// MARK: - Platform

enum Platform: String, Codable, CaseIterable, Sendable {
    case youtube
    case instagram
    case tiktok
    case snapchat
    case other

    /// Detect the source platform from a shared URL.
    static func detect(from url: URL) -> Platform {
        let host = (url.host ?? "").lowercased()
        if host.contains("youtube.com") || host.contains("youtu.be") { return .youtube }
        if host.contains("instagram.com") { return .instagram }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("snapchat.com") { return .snapchat }
        return .other
    }

    var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .snapchat: "Snapchat"
        case .other: "Web"
        }
    }

    var systemImage: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .instagram: "camera.fill"
        case .tiktok: "music.note"
        case .snapchat: "bolt.fill"
        case .other: "globe"
        }
    }
}

// MARK: - Profile

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var username: String?
    var displayName: String?
    var avatarURL: String?
    var bio: String?
    var isPublic: Bool
    var followerCount: Int
    var followingCount: Int
    var totalUpvotes: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case isPublic = "is_public"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case totalUpvotes = "total_upvotes"
        case createdAt = "created_at"
    }
}

// MARK: - ArchiveFolder

struct ArchiveFolder: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let ownerID: UUID
    var name: String
    var description: String?
    var keywords: [String]
    var coverURL: String?
    var isPublic: Bool
    var upvoteCount: Int
    var videoCount: Int
    let createdAt: Date

    /// Present when the row was fetched with an embedded owner profile.
    var owner: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case description
        case keywords
        case coverURL = "cover_url"
        case isPublic = "is_public"
        case upvoteCount = "upvote_count"
        case videoCount = "video_count"
        case createdAt = "created_at"
        case owner = "profiles"
    }
}

/// Insert payload for a new archive folder.
struct NewArchiveFolder: Encodable, Sendable {
    let ownerID: UUID
    let name: String
    var description: String? = nil
    var keywords: [String] = []
    var isPublic: Bool = false

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case name
        case description
        case keywords
        case isPublic = "is_public"
    }
}

// MARK: - VideoItem

struct VideoItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var archiveID: UUID
    let ownerID: UUID
    let platform: Platform
    let sourceURL: String
    let canonicalURL: String?
    var title: String?
    var authorName: String?
    var thumbnailURL: String?
    var durationSeconds: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case archiveID = "archive_id"
        case ownerID = "owner_id"
        case platform
        case sourceURL = "source_url"
        case canonicalURL = "canonical_url"
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
    }
}

/// Insert payload for a new video.
struct NewVideoItem: Encodable, Sendable {
    let archiveID: UUID
    let ownerID: UUID
    let platform: Platform
    let sourceURL: String
    let canonicalURL: String?
    let title: String?
    let authorName: String?
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case archiveID = "archive_id"
        case ownerID = "owner_id"
        case platform
        case sourceURL = "source_url"
        case canonicalURL = "canonical_url"
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
    }
}

// MARK: - Follow

struct Follow: Codable, Hashable, Sendable {
    let followerID: UUID
    let followingID: UUID

    enum CodingKeys: String, CodingKey {
        case followerID = "follower_id"
        case followingID = "following_id"
    }
}
