import SwiftUI

/// Public archives from all users, best first, with upvoting.
struct DiscoverView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var archives: [ArchiveFolder] = []
    @State private var upvotedIDs: Set<UUID> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let social = SocialRepository()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && archives.isEmpty {
                    ProgressView()
                } else if archives.isEmpty {
                    ContentUnavailableView(
                        "Nothing public yet",
                        systemImage: "safari",
                        description: Text("When people make their archives public, they'll show up here.")
                    )
                } else {
                    List(archives) { archive in
                        DiscoverRow(
                            archive: archive,
                            isUpvoted: upvotedIDs.contains(archive.id),
                            onToggleUpvote: { toggleUpvote(archive) }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Discover")
            .navigationDestination(for: ArchiveFolder.self) { archive in
                ArchiveDetailView(archive: archive)
            }
            .navigationDestination(for: Profile.self) { profile in
                ProfileView(profileID: profile.id)
            }
            .task { await load() }
            .refreshable { await load() }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() async {
        do {
            archives = try await social.fetchDiscoverFeed()
            if let userID = auth.currentUserID {
                upvotedIDs = try await social.fetchMyUpvotedArchiveIDs(userID: userID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleUpvote(_ archive: ArchiveFolder) {
        guard let userID = auth.currentUserID else { return }
        let wasUpvoted = upvotedIDs.contains(archive.id)

        // Optimistic UI
        if wasUpvoted {
            upvotedIDs.remove(archive.id)
        } else {
            upvotedIDs.insert(archive.id)
        }
        if let index = archives.firstIndex(where: { $0.id == archive.id }) {
            archives[index].upvoteCount += wasUpvoted ? -1 : 1
        }

        Task {
            do {
                if wasUpvoted {
                    try await social.removeUpvote(archiveID: archive.id, userID: userID)
                } else {
                    try await social.upvote(archiveID: archive.id, userID: userID)
                }
            } catch {
                await load() // roll back to server truth
            }
        }
    }
}

// MARK: - Row

struct DiscoverRow: View {
    let archive: ArchiveFolder
    let isUpvoted: Bool
    let onToggleUpvote: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: archive) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(archive.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("^[\(archive.videoCount) video](inflect: true)")
                        if let owner = archive.owner {
                            Text("·")
                            NavigationLink(value: owner) {
                                Text("@\(owner.username ?? "user")")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let description = archive.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onToggleUpvote) {
                VStack(spacing: 2) {
                    Image(systemName: isUpvoted ? "arrowshape.up.fill" : "arrowshape.up")
                    Text("\(archive.upvoteCount)")
                        .font(.caption.weight(.semibold))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(isUpvoted ? Color.accentColor : .secondary)
                .frame(minWidth: 40)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
