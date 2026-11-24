import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit

@MainActor
final class AccountSession: ObservableObject {
    @Published var user: User?
    @Published var configured = false
    @Published var error: String?
    private var listener: AuthStateDidChangeListenerHandle?
    init() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        configured = true
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
    }
    func signIn(_ email: String, _ password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    private func googleCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
            throw NSError(domain: "AccountSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google sign-in configuration is missing."])
        }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let token = result.user.idToken?.tokenString else {
            throw NSError(domain: "AccountSession", code: 2, userInfo: [NSLocalizedDescriptionKey: "Google identity token is missing."])
        }
        let credential = GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString)
        return credential
    }
    func signInWithGoogle() async throws {
        _ = try await Auth.auth().signIn(with: googleCredential())
    }
    func register(_ email: String, _ password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try? await result.user.sendEmailVerification()
    }
    func reset(_ email: String) async throws { try await Auth.auth().sendPasswordReset(withEmail: email) }
    func refresh() async throws {
        try await Auth.auth().currentUser?.reload()
        user = Auth.auth().currentUser
        objectWillChange.send()
    }
    func resend() async throws { try await Auth.auth().currentUser?.sendEmailVerification() }
    func signOut() throws { try Auth.auth().signOut(); GIDSignIn.sharedInstance.signOut() }
    func deleteAccount(password: String) async throws {
        guard let current = Auth.auth().currentUser else { throw NSError(domain: "AccountSession", code: 3) }
        if current.providerData.contains(where: { $0.providerID == "google.com" }) {
            let credential = try await googleCredential()
            _ = try await current.reauthenticate(with: credential)
        } else {
            guard let email = current.email else { throw NSError(domain: "AccountSession", code: 4) }
            _ = try await current.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
        }
        try await current.delete()
        GIDSignIn.sharedInstance.signOut()
        UserDefaults.standard.removeObject(forKey: "localArchiveOwnerUID")
    }
}

struct AccountGate<Content: View>: View {
    @StateObject private var session = AccountSession()
    @AppStorage("localArchiveOwnerUID") private var ownerUID = ""
    @State private var guest = true
    @State private var email = ""
    @State private var password = ""
    @State private var visible = false
    @State private var busy = false
    @State private var notice = ""
    @ViewBuilder var content: () -> Content
    var body: some View {
        Group {
            if !session.configured {
                VStack(spacing: 16) {
                    Text("Tarkastus Cloud").font(.title)
                    Text("Firebase configuration is missing.")
                    content().environmentObject(session)
                }
            } else if let user = session.user {
                if ownerUID == user.uid {
                    content().environmentObject(session)
                } else if ownerUID.isEmpty {
                    VStack(spacing: 16) {
                        Text("Link this device to your account")
                        Text(user.email ?? "")
                        Text("Local reports remain available offline. Cloud access is linked to this account.").font(.caption)
                        Button("Confirm") { ownerUID = user.uid }
                        Button("Sign out") { run { try session.signOut() } }
                    }.padding()
                } else {
                    VStack(spacing: 16) {
                        Text("This device is linked to another account.")
                        Text("Sign in with the original account for cloud access, or sign out to work offline.").font(.caption)
                        Button("Sign out") { run { try session.signOut() } }
                        if !notice.isEmpty { Text(notice) }
                    }.padding()
                }
            } else if guest {
                content().environmentObject(session)
            } else {
                Form {
                    if session.user != nil {
                        Text("Verify your email address.")
                        Button("Check verification") { run { try await session.refresh() } }
                        Button("Resend email") { run { try await session.resend(); notice = "Verification email sent." } }
                        Button("Sign out") { run { try session.signOut() } }
                    } else {
                        TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        HStack {
                            if visible { TextField("Password", text: $password).textInputAutocapitalization(.never) }
                            else { SecureField("Password", text: $password) }
                            Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye") }.buttonStyle(.borderless)
                        }
                        Button("Continue as guest") { guest = true; password = "" }
                        Button("Sign in") { run { try await session.signIn(email.trimmingCharacters(in: .whitespacesAndNewlines), password) } }
                        Button("Sign in with Google") { run { try await session.signInWithGoogle() } }
                        Button("Register") { run { try await session.register(email.trimmingCharacters(in: .whitespacesAndNewlines), password) } }
                        Button("Reset password") { run { try await session.reset(email.trimmingCharacters(in: .whitespacesAndNewlines)); notice = "Password reset email sent." } }
                    }
                    if busy { ProgressView() }
                    if !notice.isEmpty { Text(notice) }
                }.disabled(busy)
            }
        }
        .onChange(of: session.user?.uid) { uid in
            if uid == nil { guest = true; password = "" }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestAccountLogin"))) { _ in guest = false }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        notice = ""
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch { notice = error.localizedDescription }
        }
    }
}
