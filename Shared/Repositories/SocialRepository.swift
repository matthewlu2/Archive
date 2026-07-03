import Foundation
import Supabase

/// Discover feed, upvotes, and follow relationships.
struct SocialRepository {
    // MARK: - Discover

    /// Public archives with embedded owner profiles, best first.
    func fetchDiscoverFeed(limit: Int = 50) async throws -> [ArchiveFolder] {
        try await supabase
            .from("archives")
            .select("*, profiles!archives_owner_id_fkey(*)")
            .eq("is_public", value: true)
            .order("upvote_count", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Public archives belonging to one user.
    func fetchPublicArchives(ownerID: UUID) async throws -> [ArchiveFolder] {
        try await supabase
            .from("archives")
            .select()
            .eq("owner_id", value: ownerID)
            .eq("is_public", value: true)
            .order("upvote_count", ascending: false)
            .execute()
            .value
    }

    // MARK: - Upvotes

    /// IDs of archives the user has upvoted (to render toggle state).
    func fetchMyUpvotedArchiveIDs(userID: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let archive_id: UUID }
        let rows: [Row] = try await supabase
            .from("archive_upvotes")
            .select("archive_id")
            .eq("user_id", value: userID)
            .execute()
            .value
        return Set(rows.map(\.archive_id))
    }

    func upvote(archiveID: UUID, userID: UUID) async throws {
        struct Upvote: Encodable {
            let user_id: UUID
            let archive_id: UUID
        }
        try await supabase
            .from("archive_upvotes")
            .insert(Upvote(user_id: userID, archive_id: archiveID))
            .execute()
    }

    func removeUpvote(archiveID: UUID, userID: UUID) async throws {
        try await supabase
            .from("archive_upvotes")
            .delete()
            .eq("user_id", value: userID)
            .eq("archive_id", value: archiveID)
            .execute()
    }

    // MARK: - Follows

    func isFollowing(followerID: UUID, followingID: UUID) async throws -> Bool {
        let rows: [Follow] = try await supabase
            .from("follows")
            .select()
            .eq("follower_id", value: followerID)
            .eq("following_id", value: followingID)
            .execute()
            .value
        return !rows.isEmpty
    }

    func follow(followerID: UUID, followingID: UUID) async throws {
        struct NewFollow: Encodable {
            let follower_id: UUID
            let following_id: UUID
        }
        try await supabase
            .from("follows")
            .insert(NewFollow(follower_id: followerID, following_id: followingID))
            .execute()
    }

    func unfollow(followerID: UUID, followingID: UUID) async throws {
        try await supabase
            .from("follows")
            .delete()
            .eq("follower_id", value: followerID)
            .eq("following_id", value: followingID)
            .execute()
    }

    /// Profiles following `userID`.
    func fetchFollowers(of userID: UUID) async throws -> [Profile] {
        struct Row: Decodable {
            let profiles: Profile
        }
        let rows: [Row] = try await supabase
            .from("follows")
            .select("profiles!follows_follower_id_fkey(*)")
            .eq("following_id", value: userID)
            .execute()
            .value
        return rows.map(\.profiles)
    }

    /// Profiles that `userID` follows.
    func fetchFollowing(of userID: UUID) async throws -> [Profile] {
        struct Row: Decodable {
            let profiles: Profile
        }
        let rows: [Row] = try await supabase
            .from("follows")
            .select("profiles!follows_following_id_fkey(*)")
            .eq("follower_id", value: userID)
            .execute()
            .value
        return rows.map(\.profiles)
    }
}
