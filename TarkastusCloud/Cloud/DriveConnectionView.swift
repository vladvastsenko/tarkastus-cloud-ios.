import SwiftUI
import GoogleSignIn
import UIKit

struct DriveConnectionView: View {
    @EnvironmentObject private var store: LocalReportStore
    @EnvironmentObject private var account: AccountSession
    @AppStorage("localArchiveOwnerUID") private var ownerUID = ""
    @AppStorage("boundCompanyFolder") private var boundCompany = ""
    @AppStorage("boundGoogleIdentity") private var boundIdentity = ""
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
                Button("Synchronize") { run { client in
                    guard let identity = GIDSignIn.sharedInstance.currentUser?.userID else { throw DriveError.invalidResponse }
                    let company = folderID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !company.isEmpty, company != "root" else { notice = "Select a dedicated company folder."; return }
                    if !boundCompany.isEmpty || !boundIdentity.isEmpty {
                        guard boundCompany == company, boundIdentity == identity else {
                            notice = "This local archive is bound to another Google account or company folder. Synchronization blocked."
                            return
                        }
                    } else {
                        _ = try await client.children(of: company)
                        boundCompany = company
                        boundIdentity = identity
                    }
                    let directory = try await DirectorySync.synchronize(store: store, client: client, company: company, account: identity)
                    let imported = try await ReportSync.importMissing(store: store, client: client, company: company)
                    let exported = try await ReportSync.exportMissing(store: store, client: client, company: company)
                    let pdf = try await PDFSync.sync(client: client, company: company, account: identity)
                    notice = [directory, imported, exported, pdf].joined(separator: "\n")
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !boundCompany.isEmpty { Text("Local archive is linked to a company folder. Disconnecting does not remove this protection.").font(.caption) }
                Text("Existing shared reports are not overwritten yet.").font(.caption)
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
        guard let uid = account.user?.uid, uid == ownerUID else { notice = "Sign in to your linked account first."; return }
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
                guard let uid = account.user?.uid, uid == ownerUID else { notice = "Sign in to your linked account first."; return }
                guard let user = GIDSignIn.sharedInstance.currentUser else {
                    notice = "Connect Google Drive first."; return
                }
                let refreshed = try await user.refreshTokensIfNeeded()
                try await action(DriveClient(accessToken: refreshed.accessToken.tokenString))
            } catch { notice = error.localizedDescription }
        }
    }
}
