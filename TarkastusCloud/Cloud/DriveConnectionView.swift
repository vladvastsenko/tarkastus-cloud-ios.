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
    @Environment(\.openURL) private var openURL
    @State private var showInvitationHelp = false
    @AppStorage("privateBackupFolderID") private var privateFolder = ""
    @State private var backups: [DriveItem] = []
    @State private var selectedBackup = ""
    @State private var confirmRestore = false
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
            Section("Shared folder access") {
                Text("The folder owner invites colleagues through Google Drive. Each employee selects the shared folder in Tarkastus Cloud.")
                Button("Invite through Google Drive") { showInvitationHelp = true }
            }
            Section("Company folder") {
                TextField("Folder ID", text: $folderID).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check folder") { run { client in
                    _ = try await client.children(of: folderID.trimmingCharacters(in: .whitespacesAndNewlines))
                    notice = AppMessage.text("Folder is readable.")
                } }.disabled(folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Synchronize") { run { client in
                    guard let identity = GIDSignIn.sharedInstance.currentUser?.userID else { throw DriveError.invalidResponse }
                    let company = folderID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !company.isEmpty, company != "root" else { notice = AppMessage.text("Select a dedicated company folder."); return }
                    if !boundCompany.isEmpty || !boundIdentity.isEmpty {
                        guard boundCompany == company, boundIdentity == identity else {
                            notice = AppMessage.text("This local archive is bound to another Google account or company folder. Synchronization blocked.")
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
            Section("Private cloud backups") {
                Text("Choose your own private folder. Never share it with colleagues.")
                TextField("Private folder ID", text: $privateFolder).textInputAutocapitalization(.never).autocorrectionDisabled()
                ForEach(folders, id: \.id) { folder in
                    Button(folder.name) { privateFolder = folder.id; backups = []; selectedBackup = "" }
                }
                Button("Create separate backup") { run { client in
                    try await validateBackupFolder(client)
                    let url = try PrivateBackup.create(store: store)
                    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
                    let name = "Tarkastus-private-" + UUID().uuidString + ".json"
                    _ = try await client.upload(name: name, parent: privateFolder, data: Data(contentsOf: url), mimeType: "application/json")
                    try await loadBackups(client)
                    notice = AppMessage.text("Private backup saved.")
                } }.disabled(privateFolder.isEmpty)
                Button("Load saved backups") { run { client in try await loadBackups(client) } }.disabled(privateFolder.isEmpty)
                Picker("Saved backups", selection: $selectedBackup) {
                    Text("Select backup").tag("")
                    ForEach(backups, id: \.id) { item in Text(item.name).tag(item.id) }
                }
                Button("Restore selected backup", role: .destructive) { confirmRestore = true }.disabled(selectedBackup.isEmpty)
            }
            if busy { ProgressView() }
            if !notice.isEmpty { Text(notice) }
        }
        .sheet(isPresented: $showInvitationHelp) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Open Google Drive using the shared folder owner's account.")
                        Text("2. Find the shared Tarkastus Cloud folder.")
                        Text("3. Tap the three dots and choose Share or Manage access.")
                        Text("4. Enter the employee's email and select Editor.")
                        Text("5. Send the invitation. The employee accepts it and selects the shared folder in Tarkastus Cloud.")
                        Text("Do not share the private backup folder.").fontWeight(.semibold)
                        Button("Open Google Drive") {
                            if let url = URL(string: "https://drive.google.com/drive/my-drive") { openURL(url) }
                        }.buttonStyle(.borderedProminent)
                        Button("Cancel") { showInvitationHelp = false }
                    }.padding(24)
                }.navigationTitle("How to share a folder").navigationBarTitleDisplayMode(.inline)
            }
        }
        .confirmationDialog("Restore selected backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore", role: .destructive) { run { client in
                try await validateBackupFolder(client)
                guard try await client.children(of: privateFolder).contains(where: { $0.id == selectedBackup && $0.name.hasPrefix("Tarkastus-private-") }) else { throw DriveError.invalidResponse }
                let safety = try PrivateBackup.create(store: store)
                defer { try? FileManager.default.removeItem(at: safety.deletingLastPathComponent()) }
                _ = try await client.upload(name: "Tarkastus-private-recovery-" + UUID().uuidString + ".json", parent: privateFolder, data: Data(contentsOf: safety), mimeType: "application/json")
                let data = try await client.download(id: selectedBackup)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
                defer { try? FileManager.default.removeItem(at: url) }
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                _ = try PrivateBackup.read(url).restore(store: store)
                notice = AppMessage.text("Backup restored.")
            } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("A recovery copy will be saved before replacing local report data.") }
        .disabled(busy)
        .navigationTitle("Google Drive")
        .onAppear { email = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "" }
    }
    private func validateBackupFolder(_ client: DriveClient) async throws {
        guard privateFolder != folderID, privateFolder != boundCompany else { throw DriveError.invalidName }
        try await client.validatePrivateFolder(privateFolder, excluding: boundCompany.isEmpty ? folderID : boundCompany)
    }
    private func loadBackups(_ client: DriveClient) async throws {
        try await validateBackupFolder(client)
        backups = try await client.children(of: privateFolder).filter { $0.name.hasPrefix("Tarkastus-private-") && $0.name.hasSuffix(".json") }
        selectedBackup = ""
    }
    private func connect() {
        guard let uid = account.user?.uid, uid == ownerUID else { notice = AppMessage.text("Sign in to your linked account first."); return }
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !clientID.isEmpty,
              let controller = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
            notice = AppMessage.text("Google OAuth configuration is missing.")
            return
        }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller, hint: nil, additionalScopes: ["https://www.googleapis.com/auth/drive"])
                email = result.user.profile?.email ?? ""
                notice = AppMessage.text("Google account connected.")
            } catch { notice = AppMessage.error(error, fallback: "Cloud operation failed. Check your connection and try again.") }
        }
    }
    private func run(_ action: @escaping @MainActor (DriveClient) async throws -> Void) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                guard let uid = account.user?.uid, uid == ownerUID else { notice = AppMessage.text("Sign in to your linked account first."); return }
                guard let user = GIDSignIn.sharedInstance.currentUser else {
                    notice = AppMessage.text("Connect Google Drive first."); return
                }
                let refreshed = try await user.refreshTokensIfNeeded()
                try await action(DriveClient(accessToken: refreshed.accessToken.tokenString))
            } catch { notice = AppMessage.error(error, fallback: "Cloud operation failed. Check your connection and try again.") }
        }
    }
}
