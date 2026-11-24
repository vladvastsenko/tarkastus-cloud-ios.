import Foundation

struct GeneralInspectionReport: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var createdAt: String = ReportDate.today
    var folderPath: String = ""
    var pdfLanguage: String = ""
    var customerId: String = ""
    var siteId: String = ""
    var customerName: String = ""
    var customerBusinessId: String = ""
    var customerAddress: String = ""
    var customerPostalCode: String = ""
    var customerCity: String = ""
    var siteName: String = ""
    var headerText: String = ""
    var settingsSnapshotCreated: Bool = false
    var templateName: String = ""
    var siteAddress: String = ""
    var clientOrRepresentative: String = ""
    var clientPhone: String = ""
    var clientEmail: String = ""
    var purposeAndScope: String = ""
    var generalObservations: String = ""
    var customFieldsTitle: String = "OMAT LISÄKENTÄT"
    var customFields: [CustomReportField] = []
    var observations: [InspectionObservation] = []
    var summary: String = ""
    var inspectorName: String = ""
    var inspectorCertificateNumber: String = ""
    var inspectorPhone: String = ""
    var inspectorEmail: String = ""
    var inspectionDate: String = ReportDate.today
    var signatureStrokes: [SignatureStroke] = []
    var signatureImagePath: String = ""
    var logoPath: String = ""
    var footerText: String = ""
}

struct CustomReportField: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var label: String = ""
    var value: String = ""
    var sourceDefinitionId: String = ""
}

struct InspectionObservation: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var location: String = ""
    var description: String = ""
    var recommendedAction: String = ""
    var photos: [GeneralReportPhoto] = []
}

struct GeneralReportPhoto: Codable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var filePath: String
    var caption: String = ""
    var annotatedPath: String = ""
}

