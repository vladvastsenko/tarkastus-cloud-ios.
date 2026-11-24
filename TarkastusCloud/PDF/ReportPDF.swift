import UIKit
import Foundation

enum ReportPDF {
    private static let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private enum Block {
        case text(String, Bool)
        case photos([String], Int)
        case image(String)
    }
    static func export(_ r: InspectionReport) throws -> URL {
        func tr(_ key: String) -> String { PDFTranslation.label(key, language: r.pdfLanguage.isEmpty ? (UserDefaults.standard.string(forKey: "defaultPDFLanguage") ?? "en") : r.pdfLanguage) }
        var blocks: [Block] = [.image(r.logoPath), .text(r.headerText, false), .text(tr("VALVONTAPÖYTÄKIRJA"), true)]
        func field(_ label: String, _ value: String) { if !value.isEmpty { blocks.append(.text(tr(label) + ": " + value, false)) } }
        field("Kohde", r.siteName); field("Osoite", r.siteAddress); field("Tilaaja", r.clientOrRepresentative)
        field("Asentaja", r.installerName); field("Sertifikaatti", r.installerCertificateNumber)
        field("Työn aloitus", r.workStartDate); field("Työn päättyminen", r.workEndDate)
        blocks.append(.text(tr("ALUSTAT JA TYÖOLOSUHTEET"), true))
        field("Seinäalusta", r.wallSubstrate); field("Lattia-alusta", r.floorSubstrate)
        field("Lämpötila °C", r.roomTemperatureC); field("Ilman kosteus %", r.relativeHumidityPercent); field("Alustan kosteus %", r.substrateMoisturePercent)
        blocks.append(.text(tr("TUOTTEET"), true))
        for m in r.materials where !m.productName.isEmpty { field([tr(m.category), tr(m.surface)].filter { !$0.isEmpty }.joined(separator: " "), [m.manufacturer, m.productName, m.notes].filter { !$0.isEmpty }.joined(separator: " ")) }
        field("Lattialämmitys", r.floorHeating); field("Kynnys / kaivo mm", r.thresholdOrDrainLiftMm); field("Kaadot", r.floorSlopes)
        field("Seinä m²", r.wallAreaM2); field("Lattia m²", r.floorAreaM2)
        field("Seinän menekki l", r.wallWaterproofingConsumptionLitres); field("Lattian menekki l", r.floorWaterproofingConsumptionLitres)
        field("Seinän kuivakalvo mm", r.wallDryFilmThicknessMm); field("Lattian kuivakalvo mm", r.floorDryFilmThicknessMm)
        blocks.append(.text(tr("TARKASTUS"), true))
        field("Tulos", tr(r.inspectionResult)); field("Päivä", r.inspectionDate); field("Lisätiedot", r.additionalNotes)
        field("Tarkastaja", r.inspectorName); field("Sertifikaatti", r.inspectorCertificateNumber)
        blocks.append(.image(r.signatureImagePath))
        blocks.append(.photos(r.photos.map(\.filePath), 9))
        return try render(blocks, footer: r.footerText, name: "valvontapoytakirja_" + (r.siteAddress.isEmpty ? r.siteName : r.siteAddress))
    }
    static func export(_ r: GeneralInspectionReport) throws -> URL {
        func tr(_ key: String) -> String { PDFTranslation.label(key, language: r.pdfLanguage.isEmpty ? (UserDefaults.standard.string(forKey: "defaultPDFLanguage") ?? "en") : r.pdfLanguage) }
        var blocks: [Block] = [.image(r.logoPath), .text(r.headerText, false), .text(tr("TARKASTUSPÖYTÄKIRJA"), true)]
        func field(_ label: String, _ value: String) { if !value.isEmpty { blocks.append(.text(tr(label) + ": " + value, false)) } }
        field("Kohde", r.siteName); field("Osoite", r.siteAddress); field("Tilaaja", r.clientOrRepresentative)
        field("Tarkastuksen tarkoitus", r.purposeAndScope); field("Yleiset havainnot", r.generalObservations)
        for f in r.customFields { field(f.label, f.value) }
        blocks.append(.text(tr("TARKASTUSKOHTEET"), true))
        for o in r.observations {
            blocks.append(.text(o.location, true))
            field("Kuvaus / tilanne", o.description); field("Toimenpiteet / lisätiedot", o.recommendedAction)
            blocks.append(.photos(o.photos.map { $0.annotatedPath.isEmpty ? $0.filePath : $0.annotatedPath }, 4))
        }
        field("Yhteenveto", r.summary); field("Tarkastuspäivä", r.inspectionDate); field("Tarkastaja", r.inspectorName)
        blocks.append(.image(r.signatureImagePath))
        return try render(blocks, footer: r.footerText, name: "tarkastuspöytäkirja_" + (r.siteAddress.isEmpty ? r.siteName : r.siteAddress))
    }
    private static func render(_ blocks: [Block], footer: String, name: String) throws -> URL {
        typealias Draw = () -> Void
        var pages: [[Draw]] = [[]]
        var y: CGFloat = 36
        let width = page.width - 72
        func next() { pages.append([]); y = 36 }
        func reserve(_ h: CGFloat) -> CGFloat { if y + h > 770 { next() }; let top = y; y += h; return top }
        func image(_ img: UIImage, _ rect: CGRect) {
            let scale = min(rect.width / img.size.width, rect.height / img.size.height)
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            img.draw(in: CGRect(x: rect.midX-size.width/2, y: rect.midY-size.height/2, width: size.width, height: size.height))
        }
        for block in blocks {
            switch block {
            case let .text(value, heading):
                guard !value.isEmpty else { continue }
                let attrs: [NSAttributedString.Key: Any] = [.font: heading ? UIFont.boldSystemFont(ofSize: 15) : UIFont.systemFont(ofSize: 11)]
                let storage = NSTextStorage(string: value, attributes: attrs)
                let manager = NSLayoutManager()
                let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
                container.lineFragmentPadding = 0
                manager.addTextContainer(container); storage.addLayoutManager(manager)
                let glyphs = manager.glyphRange(for: container)
                manager.enumerateLineFragments(forGlyphRange: glyphs) { _, used, _, range, _ in
                    let top = reserve(ceil(used.height))
                    let chars = manager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
                    let line = (value as NSString).substring(with: chars)
                    pages[pages.count-1].append { (line as NSString).draw(at: CGPoint(x: 36, y: top), withAttributes: attrs) }
                }
                y += heading ? 9 : 4
            case let .image(path):
                guard let img = PhotoFiles.image(path) else { continue }
                let top = reserve(70)
                pages[pages.count-1].append { image(img, CGRect(x: 36, y: top, width: 180, height: 62)) }
            case let .photos(paths, count):
                guard !paths.isEmpty else { continue }
                if count == 9 && !pages.last!.isEmpty { next() }
                let columns = count == 9 ? 3 : 2
                let w = (width - CGFloat(columns-1)*8)/CGFloat(columns)
                let h: CGFloat = count == 9 ? 220 : 330
                for start in stride(from: 0, to: paths.count, by: columns) {
                    let top = reserve(h+8)
                    for (i,path) in paths[start..<min(start+columns, paths.count)].enumerated() {
                        let rect = CGRect(x: 36+CGFloat(i)*(w+8), y: top, width: w, height: h)
                        pages[pages.count-1].append {
                            if let img = PhotoFiles.image(path) { image(img, rect) }
                            else { ("Missing photo" as NSString).draw(at: rect.origin, withAttributes: [.font: UIFont.systemFont(ofSize: 10)]) }
                        }
                    }
                }
            }
        }
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            for (index, draws) in pages.enumerated() {
                context.beginPage()
                draws.forEach { $0() }
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
                if index == pages.count-1 { (footer as NSString).draw(in: CGRect(x: 36, y: 778, width: width, height: 30), withAttributes: attrs) }
                ("\(index+1)/\(pages.count)" as NSString).draw(at: CGPoint(x: page.width-65, y: 814), withAttributes: attrs)
            }
        }
        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)).joined(separator: "_")
        let directory = try PDFArchive.directory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(safe + ".pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
