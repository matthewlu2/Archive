import SwiftUI

/// Grid of the signed-in user's archive folders.
struct ArchivesListView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var archives: [ArchiveFolder] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showNewArchive = false
    @State private var showAddVideo = false
    @State private var ingestToast: String?

    private let repository = ArchiveRepository()

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 14)]
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && archives.isEmpty {
                    ProgressView()
                } else if archives.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(archives) { archive in
                                NavigationLink(value: archive) {
                                    ArchiveCard(archive: archive)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Archives")
            .navigationDestination(for: ArchiveFolder.self) { archive in
                ArchiveDetailView(archive: archive, onChanged: { await load() })
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Save a video link", systemImage: "link") {
                            showAddVideo = true
                        }
                        Button("New archive", systemImage: "folder.badge.plus") {
                            showNewArchive = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .archivesDidChange)) { _ in
                Task { await load() }
            }
            .sheet(isPresented: $showNewArchive) {
                NewArchiveSheet { name, isPublic in
                    await createArchive(name: name, isPublic: isPublic)
                }
            }
            .sheet(isPresented: $showAddVideo) {
                AddVideoSheet { message in
                    ingestToast = message
                    await load()
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = ingestToast {
                    ToastView(message: toast)
                        .task {
                            try? await Task.sleep(for: .seconds(2.5))
                            ingestToast = nil
                        }
                }
            }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No archives yet", systemImage: "archivebox")
        } description: {
            Text("Share a video to Archive from YouTube, TikTok, Instagram, or Snapchat — it'll be sorted into a folder automatically.")
        } actions: {
            Button("Save a video link") { showAddVideo = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func load() async {
        guard let userID = auth.currentUserID else { return }
        do {
            archives = try await repository.fetchMyArchives(ownerID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createArchive(name: String, isPublic: Bool) async {
        guard let userID = auth.currentUserID else { return }
        do {
            try await repository.createArchive(
                NewArchiveFolder(ownerID: userID, name: name, isPublic: isPublic)
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Card

struct ArchiveCard: View {
    let archive: ArchiveFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.tint.opacity(0.12))
                if let cover = archive.coverURL, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(.rect(cornerRadius: 14))
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                }
            }
            .frame(height: 110)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(archive.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if archive.isPublic {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("^[\(archive.videoCount) video](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Sheets

struct NewArchiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isPublic = false
    let onCreate: (String, Bool) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Archive name", text: $name)
                Toggle("Public on my profile", isOn: $isPublic)
            }
            .navigationTitle("New Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        Task {
                            await onCreate(trimmed, isPublic)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Paste-a-link fallback for saving videos without the share sheet.
struct AddVideoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSaved: (String) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Paste a video link", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Save Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let result = try await VideoIngestService().ingest(urlString: urlString)
                await onSaved(result.createdNewArchive
                    ? "Created “\(result.archiveName)”"
                    : "Saved to “\(result.archiveName)”")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: .capsule)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
