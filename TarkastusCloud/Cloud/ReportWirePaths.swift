import Foundation

enum ReportWirePaths {
    struct Attachment {
        let localPath: String
        let sharedPath: String
    }
    static func attachment(_ path: String, category: String, reportID: String, photo: Bool) throws -> Attachment? {
        guard !path.isEmpty else { return nil }
        guard ["reports", "tarkastus_reports"].contains(category),
              !reportID.isEmpty, !reportID.contains("/"), !reportID.contains("\\"), reportID != ".", reportID != ".." else { throw DriveError.invalidName }
        let name = (path as NSString).lastPathComponent
        let relative = category + "/" + reportID + "/" + (photo ? "photos/" : "") + name
        guard SyncPolicy.isSharedPath(relative) else { throw DriveError.invalidName }
        return Attachment(localPath: path, sharedPath: relative)
    }
    static func attachments(_ report: InspectionReport) throws -> [Attachment] {
        var result = try report.photos.compactMap { try attachment($0.filePath, category: "reports", reportID: report.id, photo: true) }
        for path in [report.logoPath, report.signatureImagePath] {
            if let item = try attachment(path, category: "reports", reportID: report.id, photo: false) { result.append(item) }
        }
        return result
    }
    static func attachments(_ report: GeneralInspectionReport) throws -> [Attachment] {
        var result: [Attachment] = []
        for observation in report.observations {
            for photo in observation.photos {
                for path in [photo.filePath, photo.annotatedPath] {
                    if let item = try attachment(path, category: "tarkastus_reports", reportID: report.id, photo: true) { result.append(item) }
                }
            }
        }
        for path in [report.logoPath, report.signatureImagePath] {
            if let item = try attachment(path, category: "tarkastus_reports", reportID: report.id, photo: false) { result.append(item) }
        }
        return result
    }
}
