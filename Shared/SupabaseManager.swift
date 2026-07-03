import Foundation
import Supabase

/// Single shared Supabase client for the app and (later) the share extension.
enum SupabaseManager {
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainLocalStorage(
                        service: "matthewlu.Archive.supabase",
                        accessGroup: SupabaseConfig.keychainAccessGroup
                    ),
                    flowType: .pkce
                )
            )
        )
    }()
}

/// Convenience global, mirroring supabase-swift example style.
let supabase = SupabaseManager.client
