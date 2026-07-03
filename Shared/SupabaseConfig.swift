import Foundation

/// Central configuration for the Supabase backend.
enum SupabaseConfig {
    static let url = URL(string: "https://tonoejtnjwbbvasmstmk.supabase.co")!

    /// Publishable key — safe to ship in the client; RLS enforces access.
    static let publishableKey = "sb_publishable_MCngRar90hg13xoDNG9c9Q_KWT7GqDy"

    /// Shared keychain access group so the Share Extension can reuse the
    /// app's session. Uses the App Group as the keychain access group —
    /// both targets carry the App Groups entitlement.
    static let keychainAccessGroup: String? = "group.matthewlu.Archive"

    /// App Group identifier used to hand pending share-extension URLs to
    /// the main app. Requires the App Groups capability on both targets.
    static let appGroupID = "group.matthewlu.Archive"
}
