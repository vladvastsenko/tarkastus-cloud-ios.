import Foundation

enum ReportSync {
    @MainActor
    static func exportMissing(store: LocalReportStore, client: DriveClient, company: String) async throws -> String {
        let sync = try await client.ensureFolder(name: "Tarkastus_Sync", parent: company)
        for item in try await client.children(of: sync) where item.name == "data" {
            guard item.mimeType == "application/vnd.google-apps.folder", (try await client.children(of: item.id)).isEmpty else { throw DriveError.invalidResponse }
        }
        let shared = try await client.ensureFolder(name: "shared_v2", parent: sync)
        let archive = store.archive
        var count = 0
        func publish(_ id: String, category: String, prepare: () async throws -> Data) async throws {
            let name = id + ".json"
            guard !id.isEmpty, SyncPolicy.isSharedPath(category + "/" + name) else { throw DriveError.invalidName }
            let folder = try await client.ensureFolder(name: category, parent: shared)
            let matches = try await client.children(of: folder).filter { $0.name == name }
            guard matches.count <= 1 else { throw DriveError.ambiguousName }
            guard matches.isEmpty else { return }
            let data = try await prepare()
            guard !(try await client.children(of: folder)).contains(where: { $0.name == name }) else { throw DriveError.ambiguousName }
            _ = try await client.upload(name: name, parent: folder, data: data, mimeType: "application/json")
            count += 1
        }
        for report in archive.waterproofing where report.templateName.isEmpty {
            try await publish(report.id, category: "reports") { try await ReportBundle.prepare(report, client: client, shared: shared) }
        }
        for report in archive.general where report.templateName.isEmpty {
            try await publish(report.id, category: "tarkastus_reports") { try await ReportBundle.prepare(report, client: client, shared: shared) }
        }
        return String(format: AppMessage.text("Exported reports: %d"), count)
    }
    // Existing reports are not overwritten until cross-platform round trips are verified.
    @MainActor
    static func importMissing(store: LocalReportStore, client: DriveClient, company: String) async throws -> String {
        let sync = try await client.ensureFolder(name: "Tarkastus_Sync", parent: company)
        for item in try await client.children(of: sync) where item.name == "data" {
            guard item.mimeType == "application/vnd.google-apps.folder", (try await client.children(of: item.id)).isEmpty else { throw DriveError.invalidResponse }
        }
        let shared = try await client.ensureFolder(name: "shared_v2", parent: sync)
        let original = store.archive
        var waterproofing: [InspectionReport] = []
        var general: [GeneralInspectionReport] = []
        for category in ["reports", "tarkastus_reports"] {
            let folder = try await client.ensureFolder(name: category, parent: shared)
            let items = try await client.children(of: folder).filter { $0.name.hasSuffix(".json") }
            guard Set(items.map(\.name)).count == items.count else { throw DriveError.ambiguousName }
            for item in items {
                guard SyncPolicy.isSharedPath(category + "/" + item.name) else { throw DriveError.invalidName }
                let id = String(item.name.dropLast(5))
                if category == "reports" {
                    guard !original.waterproofing.contains(where: { $0.id == id }) else { continue }
                    let data = try await client.download(id: item.id)
                    let metadata = try JSONDecoder().decode(InspectionReport.self, from: data)
                    guard metadata.id == id else { throw DriveError.invalidResponse }
                    guard metadata.templateName.isEmpty else { continue }
                    waterproofing.append(try await ReportBundle.receiveWaterproofing(data, client: client, shared: shared))
                } else {
                    guard !original.general.contains(where: { $0.id == id }) else { continue }
                    let data = try await client.download(id: item.id)
                    let metadata = try JSONDecoder().decode(GeneralInspectionReport.self, from: data)
                    guard metadata.id == id else { throw DriveError.invalidResponse }
                    guard metadata.templateName.isEmpty else { continue }
                    general.append(try await ReportBundle.receiveGeneral(data, client: client, shared: shared))
                }
            }
        }
        var next = store.archive
        guard next.waterproofing == original.waterproofing, next.general == original.general else { throw DriveError.invalidResponse }
        next.waterproofing.append(contentsOf: waterproofing)
        next.general.append(contentsOf: general)
        guard store.commit(next) else { throw DriveError.invalidResponse }
        return String(format: AppMessage.text("Imported reports: %d"), waterproofing.count + general.count)
    }
}
