import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var store: LocalReportStore
    @Environment(\.dismiss) private var dismiss
    @State var settings: AppSettings
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
            NavigationLink("Asiakkaat ja kohteet") { CustomerDirectoryView() }
            Button("Tallenna") { if store.saveSettings(settings) { dismiss() } }
        }
        .navigationTitle("Asetukset")
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
