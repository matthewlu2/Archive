import Foundation
import Supabase

/// CRUD for archives (folders) and their videos.
struct ArchiveRepository {
    // MARK: - Archives

    func fetchMyArchives(ownerID: UUID) async throws -> [ArchiveFolder] {
        try await supabase
            .from("archives")
            .select()
            .eq("owner_id", value: ownerID)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func fetchArchive(id: UUID) async throws -> ArchiveFolder {
        try await supabase
            .from("archives")
            .select("*, profiles!archives_owner_id_fkey(*)")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    @discardableResult
    func createArchive(_ new: NewArchiveFolder) async throws -> ArchiveFolder {
        try await supabase
            .from("archives")
            .insert(new)
            .select()
            .single()
            .execute()
            .value
    }

    func updateArchive(
        id: UUID,
        name: String? = nil,
        description: String? = nil,
        keywords: [String]? = nil,
        isPublic: Bool? = nil,
        coverURL: String? = nil
    ) async throws {
        struct Patch: Encodable {
            var name: String?
            var description: String?
            var keywords: [String]?
            var is_public: Bool?
            var cover_url: String?
        }
        try await supabase
            .from("archives")
            .update(Patch(
                name: name,
                description: description,
                keywords: keywords,
                is_public: isPublic,
                cover_url: coverURL
            ))
            .eq("id", value: id)
            .execute()
    }

    func deleteArchive(id: UUID) async throws {
        try await supabase
            .from("archives")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Videos

    func fetchVideos(archiveID: UUID) async throws -> [VideoItem] {
        try await supabase
            .from("videos")
            .select()
            .eq("archive_id", value: archiveID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    @discardableResult
    func insertVideo(_ new: NewVideoItem) async throws -> VideoItem {
        try await supabase
            .from("videos")
            .insert(new)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteVideo(id: UUID) async throws {
        try await supabase
            .from("videos")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func moveVideo(id: UUID, toArchive archiveID: UUID) async throws {
        try await supabase
            .from("videos")
            .update(["archive_id": archiveID])
            .eq("id", value: id)
            .execute()
    }
}
