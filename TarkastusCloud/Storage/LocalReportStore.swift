import Foundation
import SwiftUI

struct LocalArchive: Codable {
    var waterproofing: [InspectionReport] = []
    var general: [GeneralInspectionReport] = []
    var settings = AppSettings()
    var customers: [CustomerProfile] = []
    var sites: [CustomerSite] = []
}

@MainActor
final class LocalReportStore: ObservableObject {
    @Published private(set) var archive = LocalArchive()
    @Published var errorMessage: String?
    private var loaded = false
    private let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TarkastusCloud", isDirectory: true)
    private var file: URL { directory.appendingPathComponent("archive.json") }

    init() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                archive = try JSONDecoder().decode(LocalArchive.self, from: Data(contentsOf: file))
            }
            loaded = true
        } catch { errorMessage = AppMessage.error(error, fallback: "Local file operation failed.") }
    }

    @discardableResult
    func commit(_ next: LocalArchive) -> Bool {
        guard loaded else { errorMessage = AppMessage.text("Archive unavailable. Existing data will not be overwritten."); return false }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            archive = next
            return true
        } catch { errorMessage = AppMessage.error(error, fallback: "Local file operation failed."); return false }
    }

    func save(_ report: InspectionReport) -> Bool {
        var next = archive
        next.waterproofing.removeAll { $0.id == report.id }
        next.waterproofing.insert(report, at: 0)
        return commit(next)
    }

    func save(_ report: GeneralInspectionReport) -> Bool {
        var next = archive
        next.general.removeAll { $0.id == report.id }
        next.general.insert(report, at: 0)
        return commit(next)
    }

    func saveSettings(_ settings: AppSettings) -> Bool {
        var next = archive
        next.settings = settings
        return commit(next)
    }
}
