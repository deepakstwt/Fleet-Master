import Foundation

struct MaintenancePersonnel: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var phone: String
    var hireDate: Date
    var isActive: Bool
    var password: String
    var certifications: [Certification]
    var skills: [Skill]
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case hireDate = "hire_date"
        case isActive = "is_active"
        case password
        case certifications
        case skills
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom initializer for decoding to handle password field which isn't in the database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic properties
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        hireDate = try container.decode(Date.self, forKey: .hireDate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        // Password is not stored in the maintenance_personnel table, so make it optional during decoding
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        
        // Decode arrays
        certifications = try container.decode([Certification].self, forKey: .certifications)
        skills = try container.decode([Skill].self, forKey: .skills)
        
        // Timestamps are optional
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         email: String, 
         phone: String, 
         hireDate: Date = Date(), 
         isActive: Bool = true,
         password: String? = nil,
         certifications: [Certification] = [],
         skills: [Skill] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.hireDate = hireDate
        self.isActive = isActive
        self.password = password ?? MaintenancePersonnel.generateSecurePassword()
        self.certifications = certifications
        self.skills = skills
        self.createdAt = nil
        self.updatedAt = nil
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
    
    // Custom encoding to handle the password field
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode basic properties
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(hireDate, forKey: .hireDate)
        try container.encode(isActive, forKey: .isActive)
        
        // Only encode password when it's needed (for user creation)
        // For database updates, we'll omit it
        try container.encodeIfPresent(password.isEmpty ? nil : password, forKey: .password)
        
        // Encode arrays
        try container.encode(certifications, forKey: .certifications)
        try container.encode(skills, forKey: .skills)
        
        // Encode timestamps if they exist
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct Certification: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var issuer: String
    var category: CertificationCategory
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case issuer
        case category
    }
    
    enum CertificationCategory: String, Codable, CaseIterable {
        case technician = "Technician"
        case manager = "Manager/Supervisor"
        case other = "Other"
    }
}

struct Skill: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var proficiencyLevel: ProficiencyLevel
    var experienceYears: Int = 0
    var isCustom: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case proficiencyLevel
        case experienceYears
        case isCustom
    }
    
    enum ProficiencyLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
} 