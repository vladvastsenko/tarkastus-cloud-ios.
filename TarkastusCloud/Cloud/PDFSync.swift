import Foundation

enum PDFSync {
    static func sync(client: DriveClient, company: String, account: String) async throws -> String {
        let key = "pdfBaseline." + SyncPolicy.hash(Data((account + "|" + company).utf8))
        var baseline = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        let remote = try await client.ensureFolder(name: "PDF", parent: company)
        let sync = try await client.ensureFolder(name: "Tarkastus_Sync", parent: company)
        let conflicts = try await client.ensureFolder(name: "Conflicts", parent: sync)
        let root = try PDFArchive.directory()
        let items = try await client.children(of: remote)
        let local = try PDFArchive.files()
        var uploaded = 0, downloaded = 0, preserved = 0
        let names = Set(local.map(\.lastPathComponent)).union(items.filter { $0.mimeType == "application/pdf" }.map(\.name))
        for name in names.sorted() {
            guard !name.contains("/"), !name.contains("\\"), name != ".", name != "..", name.lowercased().hasSuffix(".pdf") else { continue }
            let matches = items.filter { $0.name == name }
            guard matches.count <= 1 else { throw DriveError.ambiguousName }
            let url = root.appendingPathComponent(name)
            let localData = local.contains(url) ? try Data(contentsOf: url) : nil
            if let item = matches.first {
                guard item.mimeType == "application/pdf" else { throw DriveError.ambiguousName }
                let remoteData = try await client.download(id: item.id)
                guard remoteData.starts(with: Data("%PDF-".utf8)) else { throw DriveError.invalidResponse }
                if let localData {
                    let lh = SyncPolicy.hash(localData), rh = SyncPolicy.hash(remoteData)
                    switch SyncPolicy.decide(local: lh, remote: rh, baseline: baseline[name]) {
                    case .unchanged:
                        baseline[name] = lh
                        UserDefaults.standard.set(baseline, forKey: key)
                        continue
                    case .upload:
                        let latest = try await client.download(id: item.id)
                        guard SyncPolicy.hash(latest) == rh else { throw DriveError.invalidResponse }
                        _ = try await client.upload(name: name, parent: remote, data: localData, mimeType: "application/pdf", existingID: item.id)
                        baseline[name] = lh
                        UserDefaults.standard.set(baseline, forKey: key)
                        uploaded += 1
                        continue
                    case .download: break
                    case .preserveLocalThenDownload:
                    let conflictName = UUID().uuidString + "_" + name
                    _ = try await client.upload(name: conflictName, parent: conflicts, data: localData, mimeType: "application/pdf")
                    preserved += 1
                    }
                }
                try remoteData.write(to: url, options: .atomic)
                baseline[name] = SyncPolicy.hash(remoteData)
                UserDefaults.standard.set(baseline, forKey: key)
                downloaded += 1
            } else if let localData {
                let current = try await client.children(of: remote)
                guard !current.contains(where: { $0.name == name }) else { throw DriveError.ambiguousName }
                _ = try await client.upload(name: name, parent: remote, data: localData, mimeType: "application/pdf")
                baseline[name] = SyncPolicy.hash(localData)
                UserDefaults.standard.set(baseline, forKey: key)
                uploaded += 1
            }
        }
        return "Uploaded: \(uploaded), downloaded: \(downloaded), conflicts preserved: \(preserved)"
    }
}
