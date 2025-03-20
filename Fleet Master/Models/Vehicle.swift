import Foundation

struct Vehicle: Identifiable, Codable {
    var id: String
    var registrationNumber: String
    var make: String
    var model: String
    var year: Int
    var vin: String
    var color: String
    var fuelType: FuelType
    var isActive: Bool
    
    // Documents and certification details
    var rcExpiryDate: Date
    var insuranceNumber: String
    var insuranceExpiryDate: Date
    var pollutionCertificateNumber: String
    var pollutionCertificateExpiryDate: Date
    
    // Additional details
    var lastServiceDate: Date?
    var nextServiceDue: Date?
    var currentOdometer: Int
    var additionalNotes: String?
    
    init(id: String = UUID().uuidString,
         registrationNumber: String,
         make: String,
         model: String,
         year: Int,
         vin: String,
         color: String,
         fuelType: FuelType,
         isActive: Bool = true,
         rcExpiryDate: Date,
         insuranceNumber: String,
         insuranceExpiryDate: Date,
         pollutionCertificateNumber: String,
         pollutionCertificateExpiryDate: Date,
         lastServiceDate: Date? = nil,
         nextServiceDue: Date? = nil,
         currentOdometer: Int = 0,
         additionalNotes: String? = nil) {
        self.id = id
        self.registrationNumber = registrationNumber
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.color = color
        self.fuelType = fuelType
        self.isActive = isActive
        self.rcExpiryDate = rcExpiryDate
        self.insuranceNumber = insuranceNumber
        self.insuranceExpiryDate = insuranceExpiryDate
        self.pollutionCertificateNumber = pollutionCertificateNumber
        self.pollutionCertificateExpiryDate = pollutionCertificateExpiryDate
        self.lastServiceDate = lastServiceDate
        self.nextServiceDue = nextServiceDue
        self.currentOdometer = currentOdometer
        self.additionalNotes = additionalNotes
    }
}

enum FuelType: String, Codable, CaseIterable {
    case petrol = "Petrol"
    case diesel = "Diesel"
    case cng = "CNG"
    case electric = "Electric"
    case hybrid = "Hybrid"
} 