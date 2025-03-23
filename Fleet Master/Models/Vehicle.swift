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
    var vehicleType: VehicleType
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
    
    // Add CodingKeys to map between Swift properties and Supabase columns
    enum CodingKeys: String, CodingKey {
        case id
        case registrationNumber = "registration_number"
        case make
        case model
        case year
        case vin
        case color
        case fuelType = "fuel_type"
        case vehicleType = "vehicle_type"
        case isActive = "is_active"
        case rcExpiryDate = "rc_expiry_date"
        case insuranceNumber = "insurance_number"
        case insuranceExpiryDate = "insurance_expiry_date"
        case pollutionCertificateNumber = "pollution_certificate_number"
        case pollutionCertificateExpiryDate = "pollution_certificate_expiry_date"
        case lastServiceDate = "last_service_date"
        case nextServiceDue = "next_service_due"
        case currentOdometer = "current_odometer"
        case additionalNotes = "additional_notes"
    }
    
    // Custom initializer for decoding to handle ISO dates from Supabase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic properties
        id = try container.decode(String.self, forKey: .id)
        registrationNumber = try container.decode(String.self, forKey: .registrationNumber)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        year = try container.decode(Int.self, forKey: .year)
        vin = try container.decode(String.self, forKey: .vin)
        color = try container.decode(String.self, forKey: .color)
        fuelType = try container.decode(FuelType.self, forKey: .fuelType)
        vehicleType = try container.decode(VehicleType.self, forKey: .vehicleType)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        // Decode required dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Required dates
        if let rcDateString = try? container.decode(String.self, forKey: .rcExpiryDate) {
            rcExpiryDate = dateFormatter.date(from: rcDateString) ?? Date()
        } else {
            rcExpiryDate = try container.decode(Date.self, forKey: .rcExpiryDate)
        }
        
        insuranceNumber = try container.decode(String.self, forKey: .insuranceNumber)
        
        if let insuranceDateString = try? container.decode(String.self, forKey: .insuranceExpiryDate) {
            insuranceExpiryDate = dateFormatter.date(from: insuranceDateString) ?? Date()
        } else {
            insuranceExpiryDate = try container.decode(Date.self, forKey: .insuranceExpiryDate)
        }
        
        pollutionCertificateNumber = try container.decode(String.self, forKey: .pollutionCertificateNumber)
        
        if let pollutionDateString = try? container.decode(String.self, forKey: .pollutionCertificateExpiryDate) {
            pollutionCertificateExpiryDate = dateFormatter.date(from: pollutionDateString) ?? Date()
        } else {
            pollutionCertificateExpiryDate = try container.decode(Date.self, forKey: .pollutionCertificateExpiryDate)
        }
        
        // Optional dates
        if let lastServiceDateString = try? container.decode(String.self, forKey: .lastServiceDate) {
            lastServiceDate = dateFormatter.date(from: lastServiceDateString)
        } else {
            lastServiceDate = try? container.decode(Date.self, forKey: .lastServiceDate)
        }
        
        if let nextServiceDueString = try? container.decode(String.self, forKey: .nextServiceDue) {
            nextServiceDue = dateFormatter.date(from: nextServiceDueString)
        } else {
            nextServiceDue = try? container.decode(Date.self, forKey: .nextServiceDue)
        }
        
        // Other properties
        currentOdometer = try container.decode(Int.self, forKey: .currentOdometer)
        additionalNotes = try? container.decode(String.self, forKey: .additionalNotes)
    }
    
    // Regular initializer
    init(id: String = UUID().uuidString,
         registrationNumber: String,
         make: String,
         model: String,
         year: Int,
         vin: String,
         color: String,
         fuelType: FuelType,
         vehicleType: VehicleType = .lmvTr,
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
        self.vehicleType = vehicleType
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
    
    // Custom encoding for dates to handle Supabase ISO format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode basic properties
        try container.encode(id, forKey: .id)
        try container.encode(registrationNumber, forKey: .registrationNumber)
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encode(year, forKey: .year)
        try container.encode(vin, forKey: .vin)
        try container.encode(color, forKey: .color)
        try container.encode(fuelType, forKey: .fuelType)
        try container.encode(vehicleType, forKey: .vehicleType)
        try container.encode(isActive, forKey: .isActive)
        
        // Format dates to ISO8601 for Supabase
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Encode dates as ISO8601 strings
        try container.encode(dateFormatter.string(from: rcExpiryDate), forKey: .rcExpiryDate)
        try container.encode(insuranceNumber, forKey: .insuranceNumber)
        try container.encode(dateFormatter.string(from: insuranceExpiryDate), forKey: .insuranceExpiryDate)
        try container.encode(pollutionCertificateNumber, forKey: .pollutionCertificateNumber)
        try container.encode(dateFormatter.string(from: pollutionCertificateExpiryDate), forKey: .pollutionCertificateExpiryDate)
        
        // Optional dates
        if let lastServiceDate = lastServiceDate {
            try container.encode(dateFormatter.string(from: lastServiceDate), forKey: .lastServiceDate)
        }
        
        if let nextServiceDue = nextServiceDue {
            try container.encode(dateFormatter.string(from: nextServiceDue), forKey: .nextServiceDue)
        }
        
        // Other properties
        try container.encode(currentOdometer, forKey: .currentOdometer)
        try container.encodeIfPresent(additionalNotes, forKey: .additionalNotes)
    }
    
    // Static date formatter for display purposes
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var formattedRCExpiryDate: String {
        return Vehicle.dateFormatter.string(from: rcExpiryDate)
    }
    
    var formattedInsuranceExpiryDate: String {
        return Vehicle.dateFormatter.string(from: insuranceExpiryDate)
    }
    
    var formattedPollutionCertificateExpiryDate: String {
        return Vehicle.dateFormatter.string(from: pollutionCertificateExpiryDate)
    }
    
    var formattedLastServiceDate: String {
        return Vehicle.dateFormatter.string(from: lastServiceDate ?? Date())
    }
    
    var formattedNextServiceDue: String {
        return Vehicle.dateFormatter.string(from: nextServiceDue ?? Date())
    }
}

enum FuelType: String, Codable, CaseIterable {
    case petrol = "Petrol"
    case diesel = "Diesel"
    case cng = "CNG"
    case electric = "Electric"
    case hybrid = "Hybrid"
}

enum VehicleType: String, Codable, CaseIterable {
    case lmvTr = "LMV-TR" // Light Motor Vehicle - Transport
    case mgv = "MGV"      // Medium Goods Vehicle
    case hmv = "HMV"      // Heavy Motor Vehicle
    case htv = "HTV"      // Heavy Transport Vehicle
    case hpmv = "HPMV"    // Heavy Passenger Motor Vehicle
    case hgmv = "HGMV"    // Heavy Goods Motor Vehicle
    case trans = "TRANS"  // Transport License Endorsement
    case psv = "PSV"      // Public Service Vehicle Badge
    
    var description: String {
        switch self {
        case .lmvTr: return "Light Motor Vehicle - Transport"
        case .mgv: return "Medium Goods Vehicle"
        case .hmv: return "Heavy Motor Vehicle"
        case .htv: return "Heavy Transport Vehicle"
        case .hpmv: return "Heavy Passenger Motor Vehicle" 
        case .hgmv: return "Heavy Goods Motor Vehicle"
        case .trans: return "Transport License Endorsement"
        case .psv: return "Public Service Vehicle Badge"
        }
    }
    
    var icon: String {
        switch self {
        case .lmvTr: return "car.fill"
        case .mgv: return "truck.pickup.side.fill"
        case .hmv, .htv: return "bus.fill"
        case .hpmv: return "bus.doubledecker.fill"
        case .hgmv: return "truck.box.fill"
        case .psv: return "person.3.fill"
        case .trans: return "arrow.triangle.swap"
        }
    }
} 