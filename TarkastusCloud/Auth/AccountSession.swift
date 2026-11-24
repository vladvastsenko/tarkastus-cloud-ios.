import SwiftUI
import FirebaseCore
import FirebaseAuth

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
    func register(_ email: String, _ password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
    }
    func reset(_ email: String) async throws { try await Auth.auth().sendPasswordReset(withEmail: email) }
    func refresh() async throws {
        try await Auth.auth().currentUser?.reload()
        user = Auth.auth().currentUser
        objectWillChange.send()
    }
    func resend() async throws { try await Auth.auth().currentUser?.sendEmailVerification() }
    func signOut() throws { try Auth.auth().signOut() }
    func deleteAccount(password: String) async throws {
        guard let current = Auth.auth().currentUser, let email = current.email else { return }
        _ = try await current.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
        try await current.delete()
    }
}

struct AccountGate<Content: View>: View {
    @StateObject private var session = AccountSession()
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
                    #if DEBUG
                    content()
                    #endif
                }
            } else if session.user?.isEmailVerified == true {
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
                        Button("Sign in") { run { try await session.signIn(email.trimmingCharacters(in: .whitespacesAndNewlines), password) } }
                        Button("Register") { run { try await session.register(email.trimmingCharacters(in: .whitespacesAndNewlines), password) } }
                        Button("Reset password") { run { try await session.reset(email.trimmingCharacters(in: .whitespacesAndNewlines)); notice = "Password reset email sent." } }
                    }
                    if busy { ProgressView() }
                    if !notice.isEmpty { Text(notice) }
                }.disabled(busy)
            }
        }
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
