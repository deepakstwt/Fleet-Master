import Foundation

struct MaintenancePersonnel: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var phone: String
    var specialization: String
    var hireDate: Date
    var isActive: Bool
    var password: String
    var certifications: [Certification]
    var skills: [Skill]
    
    init(id: String = UUID().uuidString, 
         name: String, 
         email: String, 
         phone: String, 
         specialization: String, 
         hireDate: Date = Date(), 
         isActive: Bool = true,
         certifications: [Certification] = [],
         skills: [Skill] = []) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.specialization = specialization
        self.hireDate = hireDate
        self.isActive = isActive
        self.password = String(Int.random(in: 100000...999999)) // 6-digit random password
        self.certifications = certifications
        self.skills = skills
    }
}

struct Certification: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var issuer: String
    var dateObtained: Date
    var expirationDate: Date?
    var category: CertificationCategory
    
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
    var isCustom: Bool = false
    
    enum ProficiencyLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
} 