import Foundation

struct DriveItem: Decodable {
    let id: String
    let name: String
    let mimeType: String
    let md5Checksum: String?
}
private struct DrivePage: Decodable {
    let files: [DriveItem]
    let nextPageToken: String?
}
enum DriveError: LocalizedError {
    case invalidResponse, http(Int), ambiguousName, invalidName
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid Google Drive response."
        case .http(let code): return "Google Drive request failed (HTTP \(code))."
        case .ambiguousName: return "Duplicate file or folder name in Google Drive."
        case .invalidName: return "Invalid file name."
        }
    }
}
struct DriveClient {
    let accessToken: String
    private let base = "https://www.googleapis.com/drive/v3"
    private func request(_ path: String, query: [URLQueryItem] = [], method: String = "GET", body: Data? = nil, type: String? = nil) async throws -> Data {
        guard var components = URLComponents(string: path) else { throw DriveError.invalidResponse }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw DriveError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        if let type { request.setValue(type, forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DriveError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw DriveError.http(http.statusCode) }
        return data
    }
    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
    }
    func children(of parent: String) async throws -> [DriveItem] {
        var items: [DriveItem] = []
        var token: String?
        repeat {
            var query = [URLQueryItem(name: "q", value: "'\(escaped(parent))' in parents and trashed = false"),
                         URLQueryItem(name: "fields", value: "nextPageToken,files(id,name,mimeType,md5Checksum)"),
                         URLQueryItem(name: "pageSize", value: "1000"),
                         URLQueryItem(name: "supportsAllDrives", value: "true"),
                         URLQueryItem(name: "includeItemsFromAllDrives", value: "true")]
            if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
            let page = try JSONDecoder().decode(DrivePage.self, from: await request(base + "/files", query: query))
            items += page.files
            token = page.nextPageToken
        } while token != nil
        return items
    }
    func download(id: String) async throws -> Data {
        try await request(base + "/files/" + id, query: [.init(name: "alt", value: "media"), .init(name: "supportsAllDrives", value: "true")])
    }
    func ensureFolder(name: String, parent: String) async throws -> String {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw DriveError.invalidName }
        let matches = try await children(of: parent).filter { $0.name == name }
        if matches.count > 1 { throw DriveError.ambiguousName }
        if let item = matches.first {
            guard item.mimeType == "application/vnd.google-apps.folder" else { throw DriveError.ambiguousName }
            return item.id
        }
        let body = try JSONSerialization.data(withJSONObject: ["name": name, "parents": [parent], "mimeType": "application/vnd.google-apps.folder"])
        let data = try await request(base + "/files", query: [.init(name: "fields", value: "id,name,mimeType"), .init(name: "supportsAllDrives", value: "true")], method: "POST", body: body, type: "application/json")
        return try JSONDecoder().decode(DriveItem.self, from: data).id
    }
}
