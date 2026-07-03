# Archive

Save videos from YouTube, TikTok, Instagram, and Snapchat into auto-categorized folders. Share a video to Archive from any app and it's filed into the right archive (or a new one) using on-device keyword rules. Archives can be made public, upvoted, and discovered; profiles have followers/following and a total-upvotes score.

## Targets

- **Archive** — the SwiftUI app (Archives / Discover / Profile tabs).
- **ArchiveShareExtension** — share-sheet extension that ingests shared URLs.
- **Shared/** — code compiled into both targets (Supabase client, models, metadata + categorization + ingest services, repositories).

## Backend

Supabase project **Archive** (`tonoejtnjwbbvasmstmk`, us-east-1).

- Tables: `profiles`, `archives`, `videos`, `follows`, `archive_upvotes` — all RLS-protected.
- Triggers maintain `follower_count`, `following_count`, `total_upvotes`, `upvote_count`, `video_count`, and auto-create a profile on signup.
- Storage: public `avatars` bucket (owner-write via RLS).
- Config lives in `Shared/SupabaseConfig.swift` (publishable key — safe to ship).

## Working test account

Email `test@archive.app` / password `archive-test-123` (email-confirmed, owns the public "Cooking" archive).

Debug builds support auto-login for automated testing:
`SIMCTL_CHILD_DEBUG_EMAIL=... SIMCTL_CHILD_DEBUG_PASSWORD=... xcrun simctl launch <sim> matthewlu.Archive`

## Manual setup still required

1. **Google Sign-In** (button errors until configured):
   - In Google Cloud console, create an **iOS OAuth client** (bundle id `matthewlu.Archive`) and a **Web OAuth client**.
   - Supabase Dashboard → Authentication → Providers → Google: enable, paste the **Web** client ID/secret.
   - Xcode → Archive target → Info: add `GIDClientID` (iOS client ID) and a URL scheme with the reversed iOS client ID.
2. **Email confirmations** (optional, for friction-free dev signups): Supabase Dashboard → Authentication → Sign In / Up → Email → disable "Confirm email". Until then, new signups must confirm via the emailed link before signing in.
3. **App Group on a real device**: both targets use `group.matthewlu.Archive` (share queue + shared session keychain). Works on the simulator as-is; for devices, select your team in Signing & Capabilities so Xcode registers the App Group.

## How ingest works

`VideoIngestService.ingest(url:)`:
1. Detect platform from the URL host; canonicalize the URL (dedupes re-shares).
2. Fetch metadata — oEmbed for YouTube/TikTok, OpenGraph scrape for Instagram/Snapchat.
3. `Categorizer` scores the user's archives by keyword overlap (archive `keywords` + name tokens vs. title/hashtag/author tokens). Score ≥ 2 files into the best match and merges new keywords; otherwise a new archive is created, named after the strongest keyword.
4. Insert the `videos` row; DB triggers keep counts in sync.

Playback is via each platform's web embed in a `WKWebView`, with an "Open in \<app\>" deep link fallback.
