import Foundation
import CryptoKit

enum SyncDecision: Equatable {
    case unchanged, upload, download, preserveLocalThenDownload
}
enum SyncPolicy {
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func decide(local: String?, remote: String?, baseline: String?) -> SyncDecision {
        if local == remote { return .unchanged }
        if remote == nil { return .upload }
        if local == nil { return .download }
        if local == baseline { return .download }
        if remote == baseline { return .upload }
        return .preserveLocalThenDownload
    }
    static func isSharedPath(_ path: String) -> Bool {
        let parts = path.components(separatedBy: "/")
        guard parts.count >= 2, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.contains("\\") }) else { return false }
        let ext = (parts.last! as NSString).pathExtension.lowercased()
        switch parts[0] {
        case "customers", "customer_sites":
            return parts.count == 2 && ext == "json"
        case "reports", "tarkastus_reports":
            if parts.count == 2 { return ext == "json" }
            return (parts.count == 3 || (parts.count == 4 && parts[2] == "photos")) && ["jpg", "jpeg", "png", "webp"].contains(ext)
        default: return false
        }
    }
    static let sharedDirectory = "Tarkastus_Sync/shared_v2"
    static let conflictsDirectory = "Tarkastus_Sync/Conflicts"
    static let pdfDirectory = "PDF"
}
