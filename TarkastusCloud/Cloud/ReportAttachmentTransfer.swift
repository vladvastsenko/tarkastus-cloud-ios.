import Foundation
import UIKit

enum ReportAttachmentTransfer {
    private static func resolve(_ path: String, client: DriveClient, shared: String, create: Bool) async throws -> (String, String) {
        guard SyncPolicy.isSharedPath(path) else { throw DriveError.invalidName }
        let parts = path.components(separatedBy: "/")
        var parent = shared
        for name in parts.dropLast() {
            if create { parent = try await client.ensureFolder(name: name, parent: parent) }
            else {
                let matches = try await client.children(of: parent).filter { $0.name == name }
                guard matches.count == 1, let item = matches.first, item.mimeType == "application/vnd.google-apps.folder" else { throw DriveError.invalidResponse }
                parent = item.id
            }
        }
        return (parent, parts[parts.count - 1])
    }
    static func upload(_ attachment: ReportWirePaths.Attachment, client: DriveClient, shared: String) async throws {
        let name = attachment.localPath
        guard !name.isEmpty, name == (name as NSString).lastPathComponent, name != ".", name != "..", !name.contains("\\") else { throw DriveError.invalidName }
        let data = try Data(contentsOf: PhotoFiles.directory.appendingPathComponent(name))
        guard UIImage(data: data) != nil else { throw DriveError.invalidResponse }
        let (parent, filename) = try await resolve(attachment.sharedPath, client: client, shared: shared, create: true)
        let matches = try await client.children(of: parent).filter { $0.name == filename }
        guard matches.count <= 1 else { throw DriveError.ambiguousName }
        if let existing = matches.first {
            let remote = try await client.download(id: existing.id)
            guard SyncPolicy.hash(remote) == SyncPolicy.hash(data) else { throw DriveError.ambiguousName }
            return
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        let mime = ext == "png" ? "image/png" : (ext == "webp" ? "image/webp" : "image/jpeg")
        _ = try await client.upload(name: filename, parent: parent, data: data, mimeType: mime)
    }
    static func download(_ sharedPath: String, client: DriveClient, shared: String) async throws -> String {
        let (parent, filename) = try await resolve(sharedPath, client: client, shared: shared, create: false)
        let matches = try await client.children(of: parent).filter { $0.name == filename }
        guard matches.count == 1, let item = matches.first else { throw DriveError.invalidResponse }
        let data = try await client.download(id: item.id)
        guard UIImage(data: data) != nil else { throw DriveError.invalidResponse }
        let ext = (filename as NSString).pathExtension.lowercased()
        let name = SyncPolicy.hash(data) + "." + ext
        try FileManager.default.createDirectory(at: PhotoFiles.directory, withIntermediateDirectories: true)
        let target = PhotoFiles.directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: target.path) {
            guard SyncPolicy.hash(try Data(contentsOf: target)) == SyncPolicy.hash(data) else { throw DriveError.invalidResponse }
        } else {
            try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return name
    }
}
