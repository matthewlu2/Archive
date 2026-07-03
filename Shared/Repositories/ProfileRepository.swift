import Foundation
import Supabase

/// Profile fetch/update and avatar upload.
struct ProfileRepository {
    func fetchProfile(id: UUID) async throws -> Profile {
        try await supabase
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func searchProfiles(matching query: String) async throws -> [Profile] {
        try await supabase
            .from("profiles")
            .select()
            .eq("is_public", value: true)
            .ilike("username", pattern: "%\(query)%")
            .limit(25)
            .execute()
            .value
    }

    func updateProfile(
        id: UUID,
        username: String? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil,
        isPublic: Bool? = nil
    ) async throws {
        struct Patch: Encodable {
            var username: String?
            var display_name: String?
            var bio: String?
            var avatar_url: String?
            var is_public: Bool?
        }
        try await supabase
            .from("profiles")
            .update(Patch(
                username: username,
                display_name: displayName,
                bio: bio,
                avatar_url: avatarURL,
                is_public: isPublic
            ))
            .eq("id", value: id)
            .execute()
    }

    /// Uploads avatar image data and returns its public URL.
    func uploadAvatar(userID: UUID, imageData: Data) async throws -> String {
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        try await supabase.storage
            .from("avatars")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)
        // Cache-bust since the path is stable across re-uploads.
        return "\(publicURL.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
    }
}
