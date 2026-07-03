import SwiftUI
import Supabase

/// The share sheet UI: ingests the URL and reports where it was filed.
struct ShareView: View {
    enum Phase {
        case working
        case done(message: String, isNewArchive: Bool)
        case queued
        case failed(String)
    }

    let extractURL: () async -> URL?
    let finish: () -> Void

    @State private var phase: Phase = .working

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .working:
                ProgressView()
                Text("Saving to Archive…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .done(let message, let isNew):
                Image(systemName: isNew ? "folder.badge.plus" : "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            case .queued:
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("Saved for later")
                    .font(.headline)
                Text("Open Archive to finish saving this video.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await run() }
    }

    private func run() async {
        guard let url = await extractURL() else {
            phase = .failed("Couldn't find a link in what you shared.")
            await dismissAfter(seconds: 2)
            return
        }

        if supabase.auth.currentSession != nil {
            do {
                let result = try await VideoIngestService().ingest(url: url)
                phase = .done(
                    message: result.createdNewArchive
                        ? "Created “\(result.archiveName)”"
                        : "Saved to “\(result.archiveName)”",
                    isNewArchive: result.createdNewArchive
                )
            } catch {
                // Network/session hiccup — don't lose the share.
                PendingShareQueue().enqueue(url)
                phase = .queued
            }
        } else {
            // Not signed in here (e.g. keychain sharing not set up yet):
            // hand the URL to the main app via the App Group.
            PendingShareQueue().enqueue(url)
            phase = .queued
        }
        await dismissAfter(seconds: 1.6)
    }

    private func dismissAfter(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
        finish()
    }
}
