import Foundation

enum ReportBundle {
    static func prepare(_ report: InspectionReport, client: DriveClient, shared: String) async throws -> Data {
        guard report.templateName.isEmpty else { throw DriveError.invalidResponse }
        for attachment in try ReportWirePaths.attachments(report) {
            try await ReportAttachmentTransfer.upload(attachment, client: client, shared: shared)
        }
        return try JSONEncoder().encode(report)
    }
    static func prepare(_ report: GeneralInspectionReport, client: DriveClient, shared: String) async throws -> Data {
        guard report.templateName.isEmpty else { throw DriveError.invalidResponse }
        for attachment in try ReportWirePaths.attachments(report) {
            try await ReportAttachmentTransfer.upload(attachment, client: client, shared: shared)
        }
        return try JSONEncoder().encode(report)
    }
    private static func receive(_ path: String, category: String, id: String, photo: Bool, client: DriveClient, shared: String) async throws -> String {
        guard let attachment = try ReportWirePaths.attachment(path, category: category, reportID: id, photo: photo) else { return "" }
        return try await ReportAttachmentTransfer.download(attachment.sharedPath, client: client, shared: shared)
    }
    static func receiveWaterproofing(_ data: Data, client: DriveClient, shared: String) async throws -> InspectionReport {
        var report = try JSONDecoder().decode(InspectionReport.self, from: data)
        guard report.templateName.isEmpty else { throw DriveError.invalidResponse }
        for index in report.photos.indices {
            let path = report.photos[index].filePath
            report.photos[index].filePath = try await receive(path, category: "reports", id: report.id, photo: true, client: client, shared: shared)
        }
        report.logoPath = try await receive(report.logoPath, category: "reports", id: report.id, photo: false, client: client, shared: shared)
        report.signatureImagePath = try await receive(report.signatureImagePath, category: "reports", id: report.id, photo: false, client: client, shared: shared)
        return report
    }
    static func receiveGeneral(_ data: Data, client: DriveClient, shared: String) async throws -> GeneralInspectionReport {
        var report = try JSONDecoder().decode(GeneralInspectionReport.self, from: data)
        guard report.templateName.isEmpty else { throw DriveError.invalidResponse }
        for i in report.observations.indices {
            for j in report.observations[i].photos.indices {
                let photo = report.observations[i].photos[j]
                report.observations[i].photos[j].filePath = try await receive(photo.filePath, category: "tarkastus_reports", id: report.id, photo: true, client: client, shared: shared)
                report.observations[i].photos[j].annotatedPath = try await receive(photo.annotatedPath, category: "tarkastus_reports", id: report.id, photo: true, client: client, shared: shared)
            }
        }
        report.logoPath = try await receive(report.logoPath, category: "tarkastus_reports", id: report.id, photo: false, client: client, shared: shared)
        report.signatureImagePath = try await receive(report.signatureImagePath, category: "tarkastus_reports", id: report.id, photo: false, client: client, shared: shared)
        return report
    }
}
