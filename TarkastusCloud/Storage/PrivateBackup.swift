import Foundation

struct PrivateBackup: Codable {
    let version: Int
    let archive: LocalArchive
    let images: [String: Data]
    @MainActor
    static func create(store: LocalReportStore) throws -> URL {
        var images: [String: Data] = [:]
        let fm = FileManager.default
        if fm.fileExists(atPath: PhotoFiles.directory.path) {
            for url in try fm.contentsOfDirectory(at: PhotoFiles.directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) {
                let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true else { continue }
                images[url.lastPathComponent] = try Data(contentsOf: url)
            }
        }
        let backup = PrivateBackup(version: 1, archive: store.archive, images: images)
        let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Tarkastus-private-backup.json")
        try JSONEncoder().encode(backup).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
