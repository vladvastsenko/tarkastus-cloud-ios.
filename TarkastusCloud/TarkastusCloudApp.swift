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
    @State var report: InspectionReport
    var body: some View {
        Form {
            TextField("Kohde", text: $report.siteAddress)
            TextField("Tilaaja", text: $report.clientOrRepresentative)
            TextField("Asentaja", text: $report.installerName)
            TextField("Lisätiedot", text: $report.additionalNotes, axis: .vertical)
        }
        .navigationTitle("Valvontapöytäkirja")
        .toolbar { Button("Tallenna") { _ = store.save(report) } }
    }
}

struct GeneralDraftView: View {
    @EnvironmentObject private var store: LocalReportStore
    @State var report: GeneralInspectionReport
    var body: some View {
        Form {
            TextField("Kohde", text: $report.siteAddress)
            TextField("Tilaaja", text: $report.clientOrRepresentative)
            ForEach($report.observations, id: \.id) { $observation in
                Section("Kirjaus") {
                    TextField("Tila / sijainti", text: $observation.location)
                    TextField("Kuvaus / tilanne", text: $observation.description, axis: .vertical)
                    TextField("Toimenpiteet / lisätiedot", text: $observation.recommendedAction, axis: .vertical)
                }
            }
            Button("Lisää kohde") { report.observations.append(InspectionObservation()) }
        }
        .navigationTitle("Tarkastuspöytäkirja")
        .toolbar { Button("Tallenna") { _ = store.save(report) } }
        .onAppear {
            if report.observations.isEmpty { report.observations.append(InspectionObservation()) }
        }
    }
}
