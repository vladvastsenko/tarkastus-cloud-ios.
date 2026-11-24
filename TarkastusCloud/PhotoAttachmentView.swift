import SwiftUI
import PhotosUI
import UIKit

enum PhotoFiles {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TarkastusCloud/photos", isDirectory: true)
    }
    static func save(_ data: Data) throws -> String {
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString.lowercased() + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }
    static func image(_ path: String) -> UIImage? {
        guard path == URL(fileURLWithPath: path).lastPathComponent else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(path).path)
    }
}

struct PhotoAttachmentView: View {
    @Binding var paths: [String]
    @State private var selection: [PhotosPickerItem] = []
    @State private var error: String?
    @State private var camera = false
    var body: some View {
        HStack {
            Button { camera = true } label: { Label("Ota kuva", systemImage: "camera") }
                .buttonStyle(.borderless)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            Spacer()
            PhotosPicker(selection: $selection, maxSelectionCount: 20, matching: .images) {
                Label("Valitse kuva", systemImage: "photo")
            }.buttonStyle(.borderless)
        }
        .sheet(isPresented: $camera) {
            CameraCapture { image in
                camera = false
                guard let image else { return }
                guard let data = image.jpegData(compressionQuality: 0.95) else { self.error = AppMessage.text("Could not load or save photo."); return }
                do { paths.append(try PhotoFiles.save(data)) }
                catch { self.error = AppMessage.text("Could not load or save photo.") }
            }.ignoresSafeArea()
        }
        ForEach(paths, id: \.self) { path in
            HStack {
                if let image = PhotoFiles.image(path) {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: 90)
                }
                Spacer()
                Button(role: .destructive) { paths.removeAll { $0 == path } } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel(Text("Remove photo"))
            }
        }
        .onChange(of: selection) { items in
            guard !items.isEmpty else { return }
            Task { @MainActor in
                for item in items {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self) { paths.append(try PhotoFiles.save(data)) }
                        else { self.error = AppMessage.text("Could not load or save photo.") }
                    } catch { self.error = AppMessage.text("Could not load or save photo.") }
                }
                selection = []
            }
        }
        if let error { Text(error).foregroundColor(.red) }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.originalImage] as? UIImage)
        }
    }
}
