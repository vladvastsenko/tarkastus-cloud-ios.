import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: LocalReportStore
    @Environment(\.dismiss) private var dismiss
    @State var settings: AppSettings
    @AppStorage("biometricLock") private var biometricLock = false
    @EnvironmentObject private var account: AccountSession
    @State private var confirmDelete = false
    @State private var password = ""
    @State private var accountBusy = false
    @State private var importingBackup = false
    @State private var confirmRestore = false
    @State private var pendingBackup: PrivateBackup?
    @State private var backupURL: URL?
    @State private var backupError = ""
    @State private var logo: PhotosPickerItem?
    @State private var signature: PhotosPickerItem?
    var body: some View {
        Form {
            Section("Yritys") {
                PhotosPicker(selection: $logo, matching: .images) { Text("Valitse logo") }
                if let image = PhotoFiles.image(settings.logoPath) {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: 80)
                    Button("Poista logo", role: .destructive) { settings.logoPath = "" }
                }
                TextField("Ylätunniste", text: $settings.headerText, axis: .vertical)
                TextField("Alatunniste", text: $settings.footerText, axis: .vertical)
            }
            Section("Tarkastaja") {
                TextField("Nimi", text: $settings.inspectorName)
                TextField("Sertifikaatti", text: $settings.inspectorCertificateNumber)
                TextField("Puhelin", text: $settings.inspectorPhone)
                TextField("Sähköposti", text: $settings.inspectorEmail)
                PhotosPicker(selection: $signature, matching: .images) { Text("Valitse allekirjoitus") }
                if let image = PhotoFiles.image(settings.signatureImagePath) {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: 80)
                    Button("Poista allekirjoitus", role: .destructive) { settings.signatureImagePath = "" }
                }
            }
            NavigationLink("Google Drive") { DriveConnectionView() }
            NavigationLink("Asiakkaat ja kohteet") { CustomerDirectoryView() }
            Section("Private backup") {
                Button("Create backup") {
                    do { backupURL = try PrivateBackup.create(store: store); backupError = "" }
                    catch { backupError = error.localizedDescription }
                }
                Button("Restore backup") { importingBackup = true }
                if let backupURL { ShareLink(item: backupURL) { Text("Export backup") } }
                Text("Contains personal settings and reports. Do not save in the shared company folder.").font(.caption)
                if !backupError.isEmpty { Text(backupError) }
            }
            Section("Security") {
                Toggle("Device authentication", isOn: $biometricLock)
            }
            Button("Tallenna") { if store.saveSettings(settings) { dismiss() } }
            if account.configured {
                Section("Account") {
                    Text(account.user?.email ?? "")
                    if account.user?.isEmailVerified == false {
                        Text("Email verification is recommended but optional.").font(.caption)
                        Button("Resend verification email") {
                            Task { @MainActor in
                                do { try await account.resend() }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }
                        Button("Check verification") {
                            Task { @MainActor in
                                do { try await account.refresh() }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                    Button("Sign out") {
                        do { try account.signOut() }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }.disabled(accountBusy)
            }
        }
        .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
            do { pendingBackup = try PrivateBackup.read(result.get()); confirmRestore = true }
            catch { backupError = error.localizedDescription }
        }
        .confirmationDialog("Replace local archive?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                do {
                    if let pendingBackup {
                        backupURL = try pendingBackup.restore(store: store)
                        settings = store.archive.settings
                        backupError = ""
                    }
                } catch { backupError = error.localizedDescription }
                pendingBackup = nil
            }
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        } message: { Text("A recovery copy of your current archive will be saved first.") }
        .navigationTitle("Asetukset")
        .alert("Permanently delete account?", isPresented: $confirmDelete) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = "" }
            Button("Delete account", role: .destructive) {
                let credential = password
                password = ""
                accountBusy = true
                Task { @MainActor in
                    defer { accountBusy = false }
                    do { try await account.deleteAccount(password: credential) }
                    catch { store.errorMessage = error.localizedDescription }
                }
            }
        } message: {
            Text("This deletes your login account. Local reports and shared Drive files are not deleted by this action.")
        }
        .onChange(of: logo) { item in
            Task { @MainActor in
                do { if let data = try await item?.loadTransferable(type: Data.self) { settings.logoPath = try PhotoFiles.save(data) } }
                catch { store.errorMessage = error.localizedDescription }
            }
        }
        .onChange(of: signature) { item in
            Task { @MainActor in
                do { if let data = try await item?.loadTransferable(type: Data.self) { settings.signatureImagePath = try PhotoFiles.save(data) } }
                catch { store.errorMessage = error.localizedDescription }
            }
        }
    }
}
