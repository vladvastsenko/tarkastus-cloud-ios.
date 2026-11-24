import SwiftUI
import PDFKit

enum PDFArchive {
    static func directory() throws -> URL {
        let root = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = root.appendingPathComponent("Tarkastus/PDF", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    static func files() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]).filter {
            $0.pathExtension.lowercased() == "pdf" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
struct PDFArchiveView: View {
    @State private var files: [URL] = []
    @State private var error = ""
    var body: some View {
        List {
            if !error.isEmpty { Text(error) }
            ForEach(files, id: \.self) { url in
                NavigationLink(url.lastPathComponent) {
                    PDFPreview(url: url)
                        .navigationTitle(url.deletingPathExtension().lastPathComponent)
                        .toolbar { ShareLink(item: url) }
                }
            }
        }
        .navigationTitle("PDF")
        .onAppear {
            do { files = try PDFArchive.files() }
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
