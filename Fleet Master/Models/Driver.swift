import Foundation

struct Driver: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var phone: String
    var licenseNumber: String
    var hireDate: Date
    var isActive: Bool
    var isAvailable: Bool
    var password: String
    var vehicleCategories: [String]
    
    // Indian Driving License Categories
    static let licenseCategories = [
        "LMV-TR": "Light Motor Vehicle - Transport",
        "MGV": "Medium Goods Vehicle",
        "HMV": "Heavy Motor Vehicle",
        "HTV": "Heavy Transport Vehicle",
        "HPMV": "Heavy Passenger Motor Vehicle",
        "HGMV": "Heavy Goods Motor Vehicle",
        "TRANS": "Transport License Endorsement",
        "PSV": "Public Service Vehicle Badge"
    ]
    
    // Add CodingKeys to map between Swift properties and Supabase columns
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case licenseNumber = "license_number"
        case hireDate = "hire_date"
        case isActive = "is_active"
        case isAvailable = "is_available"
        case password
        case vehicleCategories = "vehicle_categories"
    }
    
    // Custom initializer for decoding to handle ISO dates from Supabase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic properties
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        licenseNumber = try container.decode(String.self, forKey: .licenseNumber)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        
        // Password is not stored in the drivers table, so make it optional during decoding
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        
        vehicleCategories = try container.decode([String].self, forKey: .vehicleCategories)
        
        // Decode date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let hireDateString = try? container.decode(String.self, forKey: .hireDate) {
            hireDate = dateFormatter.date(from: hireDateString) ?? Date()
        } else {
            hireDate = try container.decode(Date.self, forKey: .hireDate)
        }
    }
    
    // Regular initializer
    init(id: String = UUID().uuidString, 
         name: String, 
         email: String, 
         phone: String, 
         licenseNumber: String, 
         hireDate: Date = Date(), 
         isActive: Bool = true,
         isAvailable: Bool = true,
         password: String? = nil,
         vehicleCategories: [String] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.licenseNumber = licenseNumber
        self.hireDate = hireDate
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.password = password ?? Driver.generateSecurePassword()
        self.vehicleCategories = vehicleCategories
    }
    
    // Generate a secure temporary password
    static func generateSecurePassword() -> String {
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let specialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"
        
        // Ensure at least one character from each category
        var password = String(lowercase.randomElement()!)
        password += String(uppercase.randomElement()!)
        password += String(numbers.randomElement()!)
        password += String(specialChars.randomElement()!)
        
        // Add more random characters to meet length requirement
        let allChars = lowercase + uppercase + numbers + specialChars
        while password.count < 8 {
            password += String(allChars.randomElement()!)
        }
        
        // Shuffle the characters to make the pattern less predictable
        return String(password.shuffled())
    }
    
    // Custom encoding for dates to handle Supabase ISO format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode basic properties
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(licenseNumber, forKey: .licenseNumber)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isAvailable, forKey: .isAvailable)
        
        // Only encode password when it's needed (for user creation)
        // For database updates, we'll omit it
        try container.encodeIfPresent(password.isEmpty ? nil : password, forKey: .password)
        
        try container.encode(vehicleCategories, forKey: .vehicleCategories)
        
        // Format date to ISO8601 for Supabase
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Encode date as ISO8601 string
        try container.encode(dateFormatter.string(from: hireDate), forKey: .hireDate)
    }
}
