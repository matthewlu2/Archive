import SwiftUI
import PhotosUI

/// The signed-in user's own profile tab.
struct ProfileTabView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            if let userID = auth.currentUserID {
                ProfileView(profileID: userID)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                    Task { await auth.signOut() }
                                }
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            } else {
                ProgressView()
            }
        }
    }
}

/// A user profile — own (editable) or someone else's (followable).
struct ProfileView: View {
    @Environment(AuthViewModel.self) private var auth

    let profileID: UUID

    @State private var profile: Profile?
    @State private var publicArchives: [ArchiveFolder] = []
    @State private var isFollowing = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEdit = false

    private let profiles = ProfileRepository()
    private let social = SocialRepository()
    private let archiveRepo = ArchiveRepository()

    private var isOwnProfile: Bool { auth.currentUserID == profileID }

    var body: some View {
        Group {
            if let profile {
                ScrollView {
                    VStack(spacing: 20) {
                        header(profile)
                        statsRow(profile)
                        actionsRow

                        archivesSection
                    }
                    .padding()
                }
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Profile unavailable", systemImage: "person.slash")
            }
        }
        .navigationTitle(profile?.username.map { "@\($0)" } ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ArchiveFolder.self) { archive in
            ArchiveDetailView(archive: archive)
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showEdit) {
            if let profile {
                EditProfileSheet(profile: profile) { await load() }
            }
        }
        .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private func header(_ profile: Profile) -> some View {
        VStack(spacing: 10) {
            AvatarView(urlString: profile.avatarURL, size: 88)
            VStack(spacing: 2) {
                Text(profile.displayName ?? profile.username ?? "User")
                    .font(.title3.weight(.semibold))
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func statsRow(_ profile: Profile) -> some View {
        HStack(spacing: 0) {
            NavigationLink {
                FollowListView(profileID: profile.id, mode: .followers)
            } label: {
                statCell(value: profile.followerCount, label: "Followers")
            }
            .buttonStyle(.plain)

            NavigationLink {
                FollowListView(profileID: profile.id, mode: .following)
            } label: {
                statCell(value: profile.followingCount, label: "Following")
            }
            .buttonStyle(.plain)

            statCell(value: profile.totalUpvotes, label: "Upvotes")
        }
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionsRow: some View {
        if isOwnProfile {
            Button {
                showEdit = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else if auth.isSignedIn {
            Button {
                toggleFollow()
            } label: {
                Label(isFollowing ? "Following" : "Follow",
                      systemImage: isFollowing ? "checkmark" : "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(isFollowing ? AnyPrimitiveButtonStyle(.bordered) : AnyPrimitiveButtonStyle(.borderedProminent))
        }
    }

    private var archivesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Public Archives")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if publicArchives.isEmpty {
                Text(isOwnProfile
                     ? "Make an archive public and it'll show up here."
                     : "No public archives yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                    ForEach(publicArchives) { archive in
                        NavigationLink(value: archive) {
                            ArchiveCard(archive: archive)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func load() async {
        do {
            profile = try await profiles.fetchProfile(id: profileID)
            publicArchives = try await social.fetchPublicArchives(ownerID: profileID)
            if !isOwnProfile, let me = auth.currentUserID {
                isFollowing = try await social.isFollowing(followerID: me, followingID: profileID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleFollow() {
        guard let me = auth.currentUserID else { return }
        let wasFollowing = isFollowing
        isFollowing.toggle()
        profile?.followerCount += wasFollowing ? -1 : 1

        Task {
            do {
                if wasFollowing {
                    try await social.unfollow(followerID: me, followingID: profileID)
                } else {
                    try await social.follow(followerID: me, followingID: profileID)
                }
            } catch {
                await load() // roll back to server truth
            }
        }
    }
}

/// Type-erasing wrapper so follow/unfollow can swap button styles inline.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init(_ style: some PrimitiveButtonStyle) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let urlString: String?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(.quaternary.opacity(0.6))
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.secondary)
                }
                .clipShape(.circle)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Follow lists

struct FollowListView: View {
    enum Mode: String {
        case followers = "Followers"
        case following = "Following"
    }

    let profileID: UUID
    let mode: Mode

    @State private var users: [Profile] = []
    @State private var isLoading = true

    private let social = SocialRepository()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if users.isEmpty {
                ContentUnavailableView("No \(mode.rawValue.lowercased()) yet", systemImage: "person.2")
            } else {
                List(users) { user in
                    NavigationLink {
                        ProfileView(profileID: user.id)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(urlString: user.avatarURL)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName ?? user.username ?? "User")
                                    .font(.subheadline.weight(.medium))
                                if let username = user.username {
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            switch mode {
            case .followers:
                users = (try? await social.fetchFollowers(of: profileID)) ?? []
            case .following:
                users = (try? await social.fetchFollowing(of: profileID)) ?? []
            }
            isLoading = false
        }
    }
}

// MARK: - Edit profile

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    let profile: Profile
    let onSaved: () async -> Void

    @State private var username: String
    @State private var displayName: String
    @State private var bio: String
    @State private var isPublic: Bool
    @State private var photoItem: PhotosPickerItem?
    @State private var avatarPreview: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let profiles = ProfileRepository()

    init(profile: Profile, onSaved: @escaping () async -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        _username = State(initialValue: profile.username ?? "")
        _displayName = State(initialValue: profile.displayName ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _isPublic = State(initialValue: profile.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            if let avatarPreview, let image = UIImage(data: avatarPreview) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(.circle)
                            } else {
                                AvatarView(urlString: profile.avatarURL, size: 88)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "camera.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tint)
                                            .background(.background, in: .circle)
                                    }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Username") {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Display name") {
                    TextField("Display name", text: $displayName)
                }
                Section("Bio") {
                    TextField("Say something about your archives", text: $bio, axis: .vertical)
                }
                Section {
                    Toggle("Public profile", isOn: $isPublic)
                } footer: {
                    Text("Private profiles are hidden from Discover and search.")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Edit Profile")
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
                    }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    avatarPreview = try? await newItem?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                var avatarURL: String?
                if let avatarPreview,
                   let image = UIImage(data: avatarPreview),
                   let jpeg = image.jpegData(compressionQuality: 0.8) {
                    avatarURL = try await profiles.uploadAvatar(userID: profile.id, imageData: jpeg)
                }
                try await profiles.updateProfile(
                    id: profile.id,
                    username: username.isEmpty ? nil : username,
                    displayName: displayName.isEmpty ? nil : displayName,
                    bio: bio,
                    avatarURL: avatarURL,
                    isPublic: isPublic
                )
                await onSaved()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
