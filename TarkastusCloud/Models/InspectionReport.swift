import Foundation

struct InspectionReport: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var createdAt: String = ReportDate.today
    var folderPath: String = ""
    var pdfLanguage: String = ""
    var templateName: String = ""
    var siteAddress: String = ""
    var clientOrRepresentative: String = ""
    var clientPhone: String = ""
    var clientEmail: String = ""
    var installerName: String = ""
    var installerCertificateNumber: String = ""
    var installerPhone: String = ""
    var installerEmail: String = ""
    var workStartDate: String = ""
    var workEndDate: String = ""
    var wallSubstrate: String = ""
    var floorSubstrate: String = ""
    var workInstructionsProvidedAndRead: Bool = false
    var roomTemperatureC: String = ""
    var relativeHumidityPercent: String = ""
    var substrateMoisturePercent: String = ""
    var materials: [MaterialEntry] = MaterialEntry.defaults
    var floorHeating: String = ""
    var thresholdOrDrainLiftMm: String = ""
    var floorSlopes: String = ""
    var floorSlopeRatios: [String] = []
    var wallAreaM2: String = ""
    var wallRequiredWaterproofingConsumptionPerM2: String = ""
    var wallWaterproofingConsumptionLitres: String = ""
    var floorAreaM2: String = ""
    var floorRequiredWaterproofingConsumptionPerM2: String = ""
    var floorWaterproofingConsumptionLitres: String = ""
    var wallDryFilmThicknessMm: String = ""
    var wallRequiredMinimumThicknessMm: String = ""
    var floorDryFilmThicknessMm: String = ""
    var floorRequiredMinimumThicknessMm: String = ""
    var waterproofingSpecProductKey: String = ""
    var waterproofingSpecSource: String = ""
    var inspectionResult: String = ""
    var inspectorName: String = ""
    var inspectorCertificateNumber: String = ""
    var inspectorPhone: String = ""
    var inspectorEmail: String = ""
    var inspectionDate: String = ReportDate.today
    var additionalNotes: String = ""
    var signatureStrokes: [SignatureStroke] = []
    var signatureImagePath: String = ""
    var logoPath: String = ""
    var footerText: String = ""
    var headerText: String = ""
    var settingsSnapshotCreated: Bool = false
    var customerId: String = ""
    var siteId: String = ""
    var customerName: String = ""
    var customerBusinessId: String = ""
    var customerAddress: String = ""
    var customerPostalCode: String = ""
    var customerCity: String = ""
    var siteName: String = ""
    var siteFieldValues: [SiteFieldValue] = []
    var photos: [ReportPhoto] = []
}

struct MaterialEntry: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var category: String
    var manufacturer: String = ""
    var productName: String = ""
    var notes: String = ""
    var surface: String = ""
    var consumptionPerM2: String = ""
    var dryFilmThicknessMm: String = ""
}

struct SignatureStroke: Codable, Equatable {
    var points: [SignaturePoint]
}

struct SignaturePoint: Codable, Equatable {
    var x: Float
    var y: Float
}

struct ReportPhoto: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var filePath: String
    var caption: String = ""
}

struct AppSettings: Codable, Equatable {
    var logoPath: String = ""
    var headerText: String = ""
    var footerText: String = ""
    var inspectorName: String = ""
    var inspectorCertificateNumber: String = ""
    var inspectorPhone: String = ""
    var inspectorEmail: String = ""
    var signatureStrokes: [SignatureStroke] = []
    var signatureImagePath: String = ""
}

struct InspectorProfile: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var name: String = ""
    var certificateNumber: String = ""
    var phone: String = ""
    var email: String = ""
    var signatureStrokes: [SignatureStroke] = []
    var signatureImagePath: String = ""
}

struct CustomerProfile: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var name: String = ""
    var businessId: String = ""
    var address: String = ""
    var postalCode: String = ""
    var city: String = ""
    var contactPerson: String = ""
    var phone: String = ""
    var email: String = ""
}

struct CustomerSite: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var customerId: String
    var name: String = ""
    var address: String = ""
    var fieldDefinitions: [SiteFieldDefinition] = []
}

struct SiteFieldDefinition: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var label: String = ""
}

struct SiteFieldValue: Codable, Equatable {
    var definitionId: String = ""
    var label: String = ""
    var value: String = ""
}

enum ReportDate {
    static var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

extension MaterialEntry {
    static var defaults: [MaterialEntry] {
        ["Tasoite", "Pohjuste (primer)", "Vedeneriste", "Kaivotyyppi", "Kaivolaippa / lattiakaivovahvike", "Nurkkavahvike / vahvikenauha", "Läpivientivahvike", "Läpivientien tiivistysmassa", "Kiinnityslaasti", "Laatat", "Seinäsaumaus", "Lattiasaumaus", "Elastinen saumausmassa"].flatMap { category in
            let manufacturer = ["Kaivotyyppi", "Laatat"].contains(category) ? "" : "Kiilto"
            return ["Tasoite", "Vedeneriste"].contains(category) ? ["Seinä", "Lattia"].map { MaterialEntry(category: category, manufacturer: manufacturer, surface: $0) } : [MaterialEntry(category: category, manufacturer: manufacturer)]
        }
    }
}
