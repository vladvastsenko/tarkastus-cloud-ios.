import SwiftUI
import UIKit

struct SignatureDrawingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    var onSave: (Data) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Draw your signature with your finger.")
                GeometryReader { geometry in
                    Canvas { context, size in
                        for points in strokes + [current] {
                            guard let first = points.first else { continue }
                            var path = Path()
                            path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                            for point in points.dropFirst() {
                                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                            }
                            context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                        current.append(CGPoint(x: min(1,max(0,value.location.x / geometry.size.width)), y: min(1,max(0,value.location.y / geometry.size.height))))
                    }.onEnded { _ in
                        if current.count > 1 { strokes.append(current) }
                        current = []
                    })
                }.frame(height: 200)
                Button("Clear signature") { strokes = []; current = [] }
                Button("Save signature") { save() }.buttonStyle(.borderedProminent).disabled(strokes.isEmpty)
                Spacer()
            }.padding().navigationTitle("Signature")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func save() {
        let size = CGSize(width: 1200, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(6)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for points in strokes {
                guard let first = points.first else { continue }
                cg.beginPath()
                cg.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for p in points.dropFirst() { cg.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height)) }
                cg.strokePath()
            }
        }
        if let data = image.pngData() { onSave(data); dismiss() }
    }
}
