import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var store: LocalReportStore
    @Environment(\.dismiss) private var dismiss
    @State var settings: AppSettings
    @AppStorage("biometricLock") private var biometricLock = false
    @EnvironmentObject private var account: AccountSession
    @State private var confirmDelete = false
    @State private var password = ""
    @State private var accountBusy = false
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
            Section("Security") {
                Toggle("Device authentication", isOn: $biometricLock)
            }
            Button("Tallenna") { if store.saveSettings(settings) { dismiss() } }
            if account.configured {
                Section("Account") {
                    Text(account.user?.email ?? "")
                    Button("Sign out") {
                        do { try account.signOut() }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }.disabled(accountBusy)
            }
        }
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
