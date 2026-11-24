import SwiftUI
import PDFKit

enum PDFArchive {
    static func directory() throws -> URL {
        let root = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = root.appendingPathComponent("Tarkastus/PDF", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    static func folders(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]).filter {
            guard let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return values.isDirectory == true && values.isSymbolicLink != true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    static func files(in folder: URL? = nil) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder ?? directory(), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]).filter {
            $0.pathExtension.lowercased() == "pdf" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
struct PDFArchiveView: View {
    var folder: URL? = nil
    @State private var folders: [URL] = []
    @State private var files: [URL] = []
    @State private var error = ""
    var body: some View {
        List {
            if !error.isEmpty { Text(error) }
            ForEach(folders, id: \.self) { url in
                NavigationLink { PDFArchiveView(folder: url) } label: { Label(url.lastPathComponent, systemImage: "folder") }
            }
            ForEach(files, id: \.self) { url in
                NavigationLink(url.lastPathComponent) {
                    PDFPreview(url: url)
                        .navigationTitle(url.deletingPathExtension().lastPathComponent)
                        .toolbar { ShareLink(item: url) }
                }
            }
        }
        .navigationTitle(folder?.lastPathComponent ?? "PDF")
        .onAppear {
            do {
                let directory = try folder ?? PDFArchive.directory()
                folders = try PDFArchive.folders(in: directory)
                files = try PDFArchive.files(in: directory)
            }
            catch { self.error = error.localizedDescription }
        }
    }
}
struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
