import Foundation

enum DirectorySync {
    static func exchange<T: Codable>(_ values: [T], id: (T) -> String, client: DriveClient, parent: String, account: String, company: String, category: String, conflicts: String) async throws -> [T] {
        let folder = try await client.ensureFolder(name: category, parent: parent)
        let items = try await client.children(of: folder)
        let key = "directoryBaseline." + SyncPolicy.hash(Data((account + "|" + company + "|" + category).utf8))
        let baseline = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var result: [T] = []
        var next = baseline
        var local: [String: T] = [:]
        for value in values {
            let name = id(value) + ".json"
            guard SyncPolicy.isSharedPath(category + "/" + name), !id(value).isEmpty, !id(value).contains("/"), local[name] == nil else { throw DriveError.invalidName }
            local[name] = value
        }
        let names = Set(local.keys).union(items.filter { $0.name.hasSuffix(".json") }.map(\.name))
        for name in names.sorted() {
            guard SyncPolicy.isSharedPath(category + "/" + name) else { throw DriveError.invalidName }
            let matches = items.filter { $0.name == name }
            guard matches.count <= 1 else { throw DriveError.ambiguousName }
            let item = matches.first
            let ld = try local[name].map { try encoder.encode($0) }
            var rd: Data?
            var remoteValue: T?
            if let item {
                let raw = try await client.download(id: item.id)
                let decoded = try JSONDecoder().decode(T.self, from: raw)
                guard id(decoded) + ".json" == name else { throw DriveError.invalidResponse }
                remoteValue = decoded
                rd = try encoder.encode(decoded)
            }
            let lh = ld.map(SyncPolicy.hash), rh = rd.map(SyncPolicy.hash)
            switch SyncPolicy.decide(local: lh, remote: rh, baseline: baseline[name]) {
            case .unchanged:
                if let value = local[name] ?? remoteValue { result.append(value) }
                next[name] = lh
            case .upload:
                guard let ld, let value = local[name] else { throw DriveError.invalidResponse }
                if let item {
                    let latest = try JSONDecoder().decode(T.self, from: await client.download(id: item.id))
                    guard SyncPolicy.hash(try encoder.encode(latest)) == rh else { throw DriveError.invalidResponse }
                } else {
                    guard try await !client.children(of: folder).contains(where: { $0.name == name }) else { throw DriveError.ambiguousName }
                }
                _ = try await client.upload(name: name, parent: folder, data: ld, mimeType: "application/json", existingID: item?.id)
                result.append(value); next[name] = lh
            case .download, .preserveLocalThenDownload:
                if let ld, lh != baseline[name] {
                    _ = try await client.upload(name: category + "_" + UUID().uuidString + "_" + name, parent: conflicts, data: ld, mimeType: "application/json")
                }
                guard let remoteValue else { throw DriveError.invalidResponse }
                result.append(remoteValue); next[name] = rh
            }
        }
        // Baseline persistence is deferred until the caller has committed the local archive.
        return result
    }
}
