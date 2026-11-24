import SwiftUI
import GoogleSignIn
import UIKit

struct DriveConnectionView: View {
    @EnvironmentObject private var store: LocalReportStore
    @AppStorage("driveFolderID") private var folderID = ""
    @State private var email = ""
    @State private var folders: [DriveItem] = []
    @State private var busy = false
    @State private var notice = ""
    var body: some View {
        Form {
            Section("Google Drive") {
                if !email.isEmpty { Text(email) }
                Button("Connect Google Drive") { connect() }
                Button("Disconnect", role: .destructive) {
                    GIDSignIn.sharedInstance.signOut()
                    email = ""; folderID = ""; folders = []
                }
            }
            Section("Company folder") {
                TextField("Folder ID", text: $folderID).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check folder") { run { client in
                    _ = try await client.children(of: folderID.trimmingCharacters(in: .whitespacesAndNewlines))
                    notice = "Folder is readable."
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Synchronize PDFs") { run { client in
                    notice = try await PDFSync.sync(client: client, company: folderID.trimmingCharacters(in: .whitespacesAndNewlines), account: GIDSignIn.sharedInstance.currentUser?.userID ?? email)
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Synchronize customers and sites") { run { client in
                    guard let identity = GIDSignIn.sharedInstance.currentUser?.userID else { throw DriveError.invalidResponse }
                    notice = try await DirectorySync.synchronize(store: store, client: client, company: folderID.trimmingCharacters(in: .whitespacesAndNewlines), account: identity)
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Import missing reports") { run { client in
                    notice = try await ReportSync.importMissing(store: store, client: client, company: folderID.trimmingCharacters(in: .whitespacesAndNewlines))
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("List root folders") { run { client in
                    folders = try await client.children(of: "root").filter { $0.mimeType == "application/vnd.google-apps.folder" }
                } }
                ForEach(folders, id: \.id) { folder in
                    Button { folderID = folder.id } label: {
                        HStack { Text(folder.name); Spacer(); if folderID == folder.id { Image(systemName: "checkmark") } }
                    }
                }
            }
            if busy { ProgressView() }
            if !notice.isEmpty { Text(notice) }
        }
        .disabled(busy)
        .navigationTitle("Google Drive")
        .onAppear { email = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "" }
    }
    private func connect() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !clientID.isEmpty,
              let controller = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
            notice = "Google OAuth configuration is missing."
            return
        }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller, hint: nil, additionalScopes: ["https://www.googleapis.com/auth/drive"])
                email = result.user.profile?.email ?? ""
                notice = "Google account connected."
            } catch { notice = error.localizedDescription }
        }
    }
    private func run(_ action: @escaping @MainActor (DriveClient) async throws -> Void) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                guard let user = GIDSignIn.sharedInstance.currentUser else {
                    notice = "Connect Google Drive first."; return
                }
                let refreshed = try await user.refreshTokensIfNeeded()
                try await action(DriveClient(accessToken: refreshed.accessToken.tokenString))
            } catch { notice = error.localizedDescription }
        }
    }
}
