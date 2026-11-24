import SwiftUI
import UIKit
import PhotosUI
import FirebaseAuth
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
    var body: some View {
        Form {
            Section("Language") {
                LanguageSettingsPicker()
            }
            Section("Security") {
                Toggle("Device authentication", isOn: $biometricLock)
                Text("Protect access with Face ID or Touch ID.").font(.caption)
            }
            NavigationLink("General settings") { GeneralSettingsView(settings: store.archive.settings) }
            NavigationLink("Backup and synchronization") {
                Form {
            if account.user != nil {
                NavigationLink("Google Drive") { DriveConnectionView() }
            } else {
                Button("Google Drive — sign in or register") {
                    NotificationCenter.default.post(name: Notification.Name("RequestAccountLogin"), object: nil)
                }
            }
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

                }.navigationTitle("Backup and synchronization")
            }
            Button("Back") { dismiss() }
            if account.configured && account.user == nil {
                Button("Sign in or register") { NotificationCenter.default.post(name: Notification.Name("RequestAccountLogin"), object: nil) }
            }
            if account.configured && account.user != nil {
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
        .navigationTitle("Settings and synchronization")
        .alert("Permanently delete account?", isPresented: $confirmDelete) {
            if account.user?.providerData.contains(where: { $0.providerID == "google.com" }) != true {
                SecureField("Password", text: $password)
            }
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
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: LocalReportStore
    @Environment(\.dismiss) private var dismiss
    @State var settings: AppSettings
    @State private var logo: PhotosPickerItem?
    @State private var signature: PhotosPickerItem?
    @State private var drawingSignature = false
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
                Button("Draw signature") { drawingSignature = true }
                PhotosPicker(selection: $signature, matching: .images) { Text("Valitse allekirjoitus") }
                if let image = PhotoFiles.image(settings.signatureImagePath) {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: 80)
                    Button("Poista allekirjoitus", role: .destructive) { settings.signatureImagePath = "" }
                }
            }
            Section("Inspector profiles") {
                ForEach(settings.inspectorProfiles ?? [], id: \.id) { profile in
                    Button(profile.name) {
                        settings.inspectorName = profile.name
                        settings.inspectorCertificateNumber = profile.certificateNumber
                        settings.inspectorPhone = profile.phone
                        settings.inspectorEmail = profile.email
                        settings.signatureImagePath = profile.signatureImagePath
                        settings.signatureStrokes = profile.signatureStrokes
                    }
                }.onDelete { offsets in
                    var profiles = settings.inspectorProfiles ?? []
                    profiles.remove(atOffsets: offsets)
                    settings.inspectorProfiles = profiles
                }
                Button("Save current inspector as profile") {
                    var profiles = settings.inspectorProfiles ?? []
                    let profile = InspectorProfile(name: settings.inspectorName, certificateNumber: settings.inspectorCertificateNumber, phone: settings.inspectorPhone, email: settings.inspectorEmail, signatureStrokes: settings.signatureStrokes, signatureImagePath: settings.signatureImagePath)
                    profiles.append(profile)
                    settings.inspectorProfiles = profiles
                }.disabled(settings.inspectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            NavigationLink("Asiakkaat ja kohteet") { CustomerDirectoryView() }

            Button("Tallenna") { if store.saveSettings(settings) { dismiss() } }
        }
        .navigationTitle("General settings")
        .sheet(isPresented: $drawingSignature) {
            SignatureDrawingView { data in
                do { settings.signatureImagePath = try PhotoFiles.save(data) }
                catch { store.errorMessage = error.localizedDescription }
            }
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
