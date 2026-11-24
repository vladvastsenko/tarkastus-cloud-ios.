import SwiftUI

@main
struct TarkastusCloudApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("Valvontapöytäkirja") {
                        ReportDraftView()
                    }
                    NavigationLink("Tarkastuspöytäkirja") {
                        GeneralDraftView()
                    }
                }
                .navigationTitle("Tarkastus Cloud")
            }
        }
    }
}

struct ReportDraftView: View {
    @State private var report = InspectionReport()
    var body: some View {
        Form {
            TextField("Kohde", text: $report.siteAddress)
            TextField("Tilaaja", text: $report.clientOrRepresentative)
            TextField("Asentaja", text: $report.installerName)
            TextField("Lisätiedot", text: $report.additionalNotes, axis: .vertical)
        }
        .navigationTitle("Valvontapöytäkirja")
    }
}

struct GeneralDraftView: View {
    @State private var report = GeneralInspectionReport()
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
        .onAppear {
            if report.observations.isEmpty { report.observations.append(InspectionObservation()) }
        }
    }
}
