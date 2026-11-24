import Foundation

enum DirectorySync {
    @MainActor
    static func synchronize(store: LocalReportStore, client: DriveClient, company: String, account: String) async throws -> String {
        let sync = try await client.ensureFolder(name: "Tarkastus_Sync", parent: company)
        let children = try await client.children(of: sync)
        for legacy in children where legacy.name == "data" {
            guard legacy.mimeType == "application/vnd.google-apps.folder", (try await client.children(of: legacy.id)).isEmpty else { throw DriveError.invalidResponse }
        }
        let shared = try await client.ensureFolder(name: "shared_v2", parent: sync)
        let conflicts = try await client.ensureFolder(name: "Conflicts", parent: sync)
        let original = store.archive
        let customers = try await exchange(original.customers, id: { $0.id }, client: client, parent: shared, account: account, company: company, category: "customers", conflicts: conflicts)
        let sites = try await exchange(original.sites, id: { $0.id }, client: client, parent: shared, account: account, company: company, category: "customer_sites", conflicts: conflicts)
        var next = store.archive
        guard next.customers == original.customers, next.sites == original.sites else { throw DriveError.invalidResponse }
        next.customers = customers.values
        next.sites = sites.values
        guard store.commit(next) else { throw DriveError.invalidResponse }
        UserDefaults.standard.set(customers.baseline, forKey: customers.key)
        UserDefaults.standard.set(sites.baseline, forKey: sites.key)
        return String(format: AppMessage.text("Customers: %d, sites: %d"), next.customers.count, next.sites.count)
    }

    static func exchange<T: Codable>(_ values: [T], id: (T) -> String, client: DriveClient, parent: String, account: String, company: String, category: String, conflicts: String) async throws -> (values: [T], key: String, baseline: [String: String]) {
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
                    guard !(try await client.children(of: folder)).contains(where: { $0.name == name }) else { throw DriveError.ambiguousName }
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
        return (result, key, next)
    }
}
