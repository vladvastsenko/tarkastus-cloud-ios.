import SwiftUI

@main
struct TarkastusCloudApp: App {
    @StateObject private var store = LocalReportStore()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Valvontapöytäkirja") {
                        ReportDraftView(report: InspectionReport())
                    }
                    Section("Tallennetut") {
                        ForEach(store.archive.waterproofing, id: \.id) { report in
                            NavigationLink(report.siteAddress.isEmpty ? report.createdAt : report.siteAddress) { ReportDraftView(report: report) }
                        }
                        ForEach(store.archive.general, id: \.id) { report in
                            NavigationLink(report.siteAddress.isEmpty ? report.createdAt : report.siteAddress) { GeneralDraftView(report: report) }
                        }
                    }
                    NavigationLink("Tarkastuspöytäkirja") {
                        GeneralDraftView(report: GeneralInspectionReport())
                    }
                }
                .navigationTitle("Tarkastus Cloud")
                .toolbar { NavigationLink(destination: SettingsView(settings: store.archive.settings)) { Image(systemName: "gearshape") } }
                .environmentObject(store)
                .alert("Error", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
            }
        }
    }
}

struct ReportDraftView: View {
    @EnvironmentObject private var store: LocalReportStore
    @State private var exported: URL?
    @State var report: InspectionReport
    var body: some View {
        Form {
            Section("Asiakas ja kohde") {
                Picker("Asiakas", selection: $report.customerId) {
                    Text("—").tag("")
                    ForEach(store.archive.customers, id: \.id) { customer in
                        Text(customer.name).tag(customer.id)
                    }
                }
                .onChange(of: report.customerId) { id in
                    report.siteId = ""
                    if let customer = store.archive.customers.first(where: { $0.id == id }) {
                        report.customerName = customer.name
                        report.customerBusinessId = customer.businessId
                        report.customerAddress = customer.address
                        report.customerPostalCode = customer.postalCode
                        report.customerCity = customer.city
                        report.clientOrRepresentative = customer.contactPerson.isEmpty ? customer.name : customer.contactPerson
                        report.clientPhone = customer.phone
                        report.clientEmail = customer.email
                    }
                }
                Picker("Kohde", selection: $report.siteId) {
                    Text("—").tag("")
                    ForEach(store.archive.sites.filter { $0.customerId == report.customerId }, id: \.id) { site in
                        Text(site.name + (site.address.isEmpty ? "" : " – " + site.address)).tag(site.id)
                    }
                }
                .onChange(of: report.siteId) { id in
                    if let site = store.archive.sites.first(where: { $0.id == id }) {
                        report.siteName = site.name
                        report.siteAddress = site.address
                    }
                }
            }
            TextField("Kohde", text: $report.siteAddress)
            TextField("Tilaaja", text: $report.clientOrRepresentative)
            TextField("Asentaja", text: $report.installerName)
            Section("Työmaa ja osapuolet") {
            TextField("Kohteen nimi", text: $report.siteName)
            TextField("Tilaajan puhelin", text: $report.clientPhone)
            TextField("Tilaajan sähköposti", text: $report.clientEmail)
            TextField("Asentajan sertifikaatti", text: $report.installerCertificateNumber)
            TextField("Asentajan puhelin", text: $report.installerPhone)
            TextField("Asentajan sähköposti", text: $report.installerEmail)
            TextField("Työn aloitus", text: $report.workStartDate)
            TextField("Työn päättyminen", text: $report.workEndDate)
            }
            Section("Alustat ja työolosuhteet") {
            TextField("Seinäalusta", text: $report.wallSubstrate)
            TextField("Lattia-alusta", text: $report.floorSubstrate)
            TextField("Lämpötila °C", text: $report.roomTemperatureC)
            TextField("Ilman kosteus %", text: $report.relativeHumidityPercent)
            TextField("Alustan kosteus %", text: $report.substrateMoisturePercent)
                Toggle("Työohjeet annettu ja luettu", isOn: $report.workInstructionsProvidedAndRead)
            }
            Section("Tuotteet") {
                ForEach($report.materials, id: \.id) { $material in
                    DisclosureGroup(material.category + " " + material.surface) {
                        TextField("Valmistaja", text: $material.manufacturer)
                        TextField("Tuote", text: $material.productName)
                        TextField("Lisätiedot", text: $material.notes)
                    }
                }
            }
            Section("Rakenteet ja mitat") {
            TextField("Lattialämmitys", text: $report.floorHeating)
            TextField("Kynnys / kaivo mm", text: $report.thresholdOrDrainLiftMm)
            TextField("Lattian kaadot", text: $report.floorSlopes)
            TextField("Seinä m²", text: $report.wallAreaM2)
            TextField("Seinän vaadittu menekki", text: $report.wallRequiredWaterproofingConsumptionPerM2)
            TextField("Seinän menekki l", text: $report.wallWaterproofingConsumptionLitres)
            TextField("Lattia m²", text: $report.floorAreaM2)
            TextField("Lattian vaadittu menekki", text: $report.floorRequiredWaterproofingConsumptionPerM2)
            TextField("Lattian menekki l", text: $report.floorWaterproofingConsumptionLitres)
            TextField("Seinän kuivakalvo mm", text: $report.wallDryFilmThicknessMm)
            TextField("Seinän vähimmäispaksuus mm", text: $report.wallRequiredMinimumThicknessMm)
            TextField("Lattian kuivakalvo mm", text: $report.floorDryFilmThicknessMm)
            TextField("Lattian vähimmäispaksuus mm", text: $report.floorRequiredMinimumThicknessMm)
            }
            Section("Tarkastus") {
                Picker("Tulos", selection: $report.inspectionResult) {
                    Text("—").tag("")
                    Text("Hyväksytty").tag("Hyväksytty")
                    Text("Hylätty").tag("Hylätty")
                }
                TextField("Tarkastuspäivä", text: $report.inspectionDate)
                TextField("Lisätiedot", text: $report.additionalNotes, axis: .vertical)
            }
            PhotoAttachmentView(paths: Binding(get: { report.photos.map(\.filePath) }, set: { paths in
                report.photos = paths.map { path in report.photos.first(where: { $0.filePath == path }) ?? ReportPhoto(filePath: path) }
            }))
        }
        .navigationTitle("Valvontapöytäkirja")
        .toolbar { Button("Tallenna") { applySettings(); _ = store.save(report) } }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Luo PDF") {
                    applySettings()
                    guard store.save(report) else { return }
                    do { exported = try ReportPDF.export(report) }
                    catch { store.errorMessage = error.localizedDescription }
                }
                if let exported { ShareLink(item: exported) { Label("Jaa PDF", systemImage: "square.and.arrow.up") } }
            }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
        }
    }
    private func applySettings() {
        guard !report.settingsSnapshotCreated else { return }
        let settings = store.archive.settings
        report.logoPath = settings.logoPath
        report.headerText = settings.headerText
        report.footerText = settings.footerText
        report.inspectorName = settings.inspectorName
        report.inspectorCertificateNumber = settings.inspectorCertificateNumber
        report.inspectorPhone = settings.inspectorPhone
        report.inspectorEmail = settings.inspectorEmail
        report.signatureImagePath = settings.signatureImagePath
        report.signatureStrokes = settings.signatureStrokes
        report.settingsSnapshotCreated = true
    }
}

struct GeneralDraftView: View {
    @EnvironmentObject private var store: LocalReportStore
    @State private var exported: URL?
    @State var report: GeneralInspectionReport
    var body: some View {
        Form {
            Section("Asiakas ja kohde") {
                Picker("Asiakas", selection: $report.customerId) {
                    Text("—").tag("")
                    ForEach(store.archive.customers, id: \.id) { customer in
                        Text(customer.name).tag(customer.id)
                    }
                }
                .onChange(of: report.customerId) { id in
                    report.siteId = ""
                    if let customer = store.archive.customers.first(where: { $0.id == id }) {
                        report.customerName = customer.name
                        report.customerBusinessId = customer.businessId
                        report.customerAddress = customer.address
                        report.customerPostalCode = customer.postalCode
                        report.customerCity = customer.city
                        report.clientOrRepresentative = customer.contactPerson.isEmpty ? customer.name : customer.contactPerson
                        report.clientPhone = customer.phone
                        report.clientEmail = customer.email
                    }
                }
                Picker("Kohde", selection: $report.siteId) {
                    Text("—").tag("")
                    ForEach(store.archive.sites.filter { $0.customerId == report.customerId }, id: \.id) { site in
                        Text(site.name + (site.address.isEmpty ? "" : " – " + site.address)).tag(site.id)
                    }
                }
                .onChange(of: report.siteId) { id in
                    if let site = store.archive.sites.first(where: { $0.id == id }) {
                        report.siteName = site.name
                        report.siteAddress = site.address
                    }
                }
            }
            TextField("Kohde", text: $report.siteAddress)
            TextField("Tilaaja", text: $report.clientOrRepresentative)
            TextField("Kohteen nimi", text: $report.siteName)
            TextField("Tarkastuksen tarkoitus", text: $report.purposeAndScope, axis: .vertical)
            TextField("Yleiset havainnot", text: $report.generalObservations, axis: .vertical)
            ForEach($report.observations, id: \.id) { $observation in
                Section("Kirjaus") {
                    TextField("Tila / sijainti", text: $observation.location)
                    TextField("Kuvaus / tilanne", text: $observation.description, axis: .vertical)
                    TextField("Toimenpiteet / lisätiedot", text: $observation.recommendedAction, axis: .vertical)
                    PhotoAttachmentView(paths: Binding(get: { observation.photos.map(\.filePath) }, set: { paths in
                        observation.photos = paths.map { path in observation.photos.first(where: { $0.filePath == path }) ?? GeneralReportPhoto(filePath: path) }
                    }))
                }
            }
            Button("Lisää kohde") { report.observations.append(InspectionObservation()) }
            TextField("Yhteenveto", text: $report.summary, axis: .vertical)
            TextField("Tarkastuspäivä", text: $report.inspectionDate)
        }
        .navigationTitle("Tarkastuspöytäkirja")
        .toolbar { Button("Tallenna") { applySettings(); _ = store.save(report) } }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Luo PDF") {
                    applySettings()
                    guard store.save(report) else { return }
                    do { exported = try ReportPDF.export(report) }
                    catch { store.errorMessage = error.localizedDescription }
                }
                if let exported { ShareLink(item: exported) { Label("Jaa PDF", systemImage: "square.and.arrow.up") } }
            }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
        }
        .onAppear {
            if report.observations.isEmpty { report.observations.append(InspectionObservation()) }
        }
    }
    private func applySettings() {
        guard !report.settingsSnapshotCreated else { return }
        let settings = store.archive.settings
        report.logoPath = settings.logoPath
        report.headerText = settings.headerText
        report.footerText = settings.footerText
        report.inspectorName = settings.inspectorName
        report.inspectorCertificateNumber = settings.inspectorCertificateNumber
        report.inspectorPhone = settings.inspectorPhone
        report.inspectorEmail = settings.inspectorEmail
        report.signatureImagePath = settings.signatureImagePath
        report.signatureStrokes = settings.signatureStrokes
        report.settingsSnapshotCreated = true
    }
}
