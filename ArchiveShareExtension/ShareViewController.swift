import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Principal class of the share extension: pulls the shared URL out of the
/// extension context and hosts the SwiftUI flow.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let shareView = ShareView(
            extractURL: { [weak self] in await self?.extractSharedURL() },
            finish: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        let host = UIHostingController(rootView: shareView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// Finds the first URL attachment (or a URL inside shared plain text).
    private func extractSharedURL() async -> URL? {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadURL() {
                return url
            }
        }
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await provider.loadText(),
               let match = text.split(separator: " ").first(where: { $0.hasPrefix("http") }),
               let url = URL(string: String(match)) {
                return url
            }
        }
        return nil
    }
}

private extension NSItemProvider {
    func loadURL() async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.url.identifier) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadText() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item as? String)
                }
            }
        }
    }
}
