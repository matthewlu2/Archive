import SwiftUI

/// Videos inside one archive, with edit/public controls for the owner.
struct ArchiveDetailView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let archive: ArchiveFolder
    var onChanged: (() async -> Void)? = nil

    @State private var videos: [VideoItem] = []
    @State private var isLoading = true
    @State private var isPublic: Bool
    @State private var errorMessage: String?
    @State private var showEdit = false

    private let repository = ArchiveRepository()

    private var isOwner: Bool { auth.currentUserID == archive.ownerID }

    init(archive: ArchiveFolder, onChanged: (() async -> Void)? = nil) {
        self.archive = archive
        self.onChanged = onChanged
        _isPublic = State(initialValue: archive.isPublic)
    }

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView()
            } else if videos.isEmpty {
                ContentUnavailableView(
                    "No videos yet",
                    systemImage: "film",
                    description: Text("Videos you share to Archive that match this folder will land here.")
                )
            } else {
                List {
                    ForEach(videos) { video in
                        NavigationLink(value: video) {
                            VideoRow(video: video)
                        }
                    }
                    .onDelete { indexSet in
                        guard isOwner else { return }
                        deleteVideos(at: indexSet)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(archive.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: VideoItem.self) { video in
            VideoPlayerView(video: video)
        }
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Public on my profile", systemImage: "globe", isOn: $isPublic)
                        Button("Edit archive", systemImage: "pencil") { showEdit = true }
                        Button("Delete archive", systemImage: "trash", role: .destructive) {
                            deleteArchive()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onChange(of: isPublic) { _, newValue in
            guard isOwner else { return }
            Task {
                try? await repository.updateArchive(id: archive.id, isPublic: newValue)
                await onChanged?()
            }
        }
        .sheet(isPresented: $showEdit) {
            EditArchiveSheet(archive: archive) {
                await onChanged?()
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        do {
            videos = try await repository.fetchVideos(archiveID: archive.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteVideos(at indexSet: IndexSet) {
        let toDelete = indexSet.map { videos[$0] }
        videos.remove(atOffsets: indexSet)
        Task {
            for video in toDelete {
                try? await repository.deleteVideo(id: video.id)
            }
            await onChanged?()
        }
    }

    private func deleteArchive() {
        Task {
            do {
                try await repository.deleteArchive(id: archive.id)
                await onChanged?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Row

struct VideoRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.6))
                if let thumb = video.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView().controlSize(.small)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                } else {
                    Image(systemName: video.platform.systemImage)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 60)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title ?? video.sourceURL)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: video.platform.systemImage)
                        .font(.caption2)
                    Text(video.authorName ?? video.platform.displayName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit sheet

struct EditArchiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let archive: ArchiveFolder
    let onSaved: () async -> Void

    @State private var name: String
    @State private var descriptionText: String
    @State private var keywordsText: String

    private let repository = ArchiveRepository()

    init(archive: ArchiveFolder, onSaved: @escaping () async -> Void) {
        self.archive = archive
        self.onSaved = onSaved
        _name = State(initialValue: archive.name)
        _descriptionText = State(initialValue: archive.description ?? "")
        _keywordsText = State(initialValue: archive.keywords.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Description") {
                    TextField("Optional description", text: $descriptionText, axis: .vertical)
                }
                Section {
                    TextField("comma, separated, keywords", text: $keywordsText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Keywords")
                } footer: {
                    Text("Shared videos whose titles match these keywords are filed into this archive.")
                }
            }
            .navigationTitle("Edit Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let keywords = keywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        Task {
            try? await repository.updateArchive(
                id: archive.id,
                name: name.trimmingCharacters(in: .whitespaces),
                description: descriptionText.isEmpty ? nil : descriptionText,
                keywords: keywords
            )
            await onSaved()
            dismiss()
        }
    }
}
