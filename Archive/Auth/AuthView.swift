import SwiftUI

/// Sign-in / sign-up screen: email+password plus Google.
struct AuthView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @State private var isBusy = false

    var body: some View {
        @Bindable var auth = auth
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))

                        SecureField("Password", text: $password)
                            .textContentType(isSigningUp ? .newPassword : .password)
                            .padding(14)
                            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))

                        if let message = auth.errorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            submitEmail()
                        } label: {
                            Group {
                                if isBusy {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSigningUp ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || password.isEmpty || isBusy)

                        Button(isSigningUp ? "Have an account? Sign in" : "New here? Create an account") {
                            isSigningUp.toggle()
                            auth.errorMessage = nil
                        }
                        .font(.subheadline)
                    }

                    divider

                    Button {
                        Task {
                            isBusy = true
                            await auth.signInWithGoogle()
                            isBusy = false
                        }
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }
                .padding(24)
            }
            .navigationTitle("Archive")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("All your videos, one place")
                .font(.title3.weight(.semibold))
            Text("Save videos from YouTube, TikTok, Instagram, and Snapchat into smart folders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(.quaternary).frame(height: 1)
            Text("or").font(.caption).foregroundStyle(.secondary)
            Rectangle().fill(.quaternary).frame(height: 1)
        }
    }

    private func submitEmail() {
        Task {
            isBusy = true
            if isSigningUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
            isBusy = false
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthViewModel())
}
