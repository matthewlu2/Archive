import SwiftUI

/// Root tabs: the user's archives, the public discover feed, and profile.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Archives", systemImage: "archivebox.fill") {
                ArchivesListView()
            }
            Tab("Discover", systemImage: "safari.fill") {
                DiscoverView()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill") {
                ProfileTabView()
            }
        }
    }
}
