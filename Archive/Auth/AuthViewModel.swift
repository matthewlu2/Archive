import Foundation
import Observation
import UIKit
import Supabase
import GoogleSignIn

/// Observes the Supabase session and exposes sign-in/up/out actions.
@Observable
final class AuthViewModel {
    private(set) var session: Session?
    private(set) var isLoading = true
    var errorMessage: String?

    var currentUserID: UUID? { session?.user.id }
    var isSignedIn: Bool { session != nil }

    private var authListenerTask: Task<Void, Never>?

    init() {
        authListenerTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession, .signedIn, .signedOut, .tokenRefreshed, .userUpdated:
                    self.session = session
                    self.isLoading = false
                default:
                    break
                }
            }
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Email / password

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            if response.session == nil {
                // Email confirmation is enabled — no session until the link is tapped.
                errorMessage = "Check your email to confirm your account, then sign in."
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        errorMessage = nil
        do {
            guard let rootViewController = Self.topViewController() else {
                errorMessage = "Couldn't find a window to present Google Sign-In."
                return
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google didn't return an ID token."
                return
            }
            try await supabase.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            ))
        } catch let error as GIDSignInError where error.code == .canceled {
            // User dismissed the sheet — not an error worth surfacing.
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Sign out

    func signOut() async {
        errorMessage = nil
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Helpers

    private func friendlyMessage(for error: Error) -> String {
        error.localizedDescription
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
