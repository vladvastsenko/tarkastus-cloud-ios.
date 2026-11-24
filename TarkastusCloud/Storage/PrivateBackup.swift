import Foundation
import UIKit

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
    static func read(_ url: URL) throws -> PrivateBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let backup = try JSONDecoder().decode(PrivateBackup.self, from: Data(contentsOf: url))
        guard backup.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        for (name, data) in backup.images {
            guard !name.isEmpty, name == (name as NSString).lastPathComponent, name != ".", name != "..", !name.contains("\\"), UIImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }
        }
        return backup
    }
    @MainActor
    func restore(store: LocalReportStore) throws -> URL {
        let fm = FileManager.default
        let safety = try Self.create(store: store)
        let recovery = try PDFArchive.directory().deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
        try fm.createDirectory(at: recovery, withIntermediateDirectories: true)
        let saved = recovery.appendingPathComponent(UUID().uuidString + ".json")
        try fm.copyItem(at: safety, to: saved)
        try fm.createDirectory(at: PhotoFiles.directory, withIntermediateDirectories: true)
        // Never overwrite a different existing image; abort before changing the archive.
        for (name, data) in images {
            let target = PhotoFiles.directory.appendingPathComponent(name)
            if fm.fileExists(atPath: target.path) {
                guard try Data(contentsOf: target) == data else { throw CocoaError(.fileWriteFileExists) }
            }
        }
        for (name, data) in images {
            let target = PhotoFiles.directory.appendingPathComponent(name)
            if !fm.fileExists(atPath: target.path) {
                try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
        guard store.commit(archive) else { throw CocoaError(.fileWriteUnknown) }
        return saved
    }
}
