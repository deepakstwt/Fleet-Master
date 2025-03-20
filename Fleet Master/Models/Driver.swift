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
    
    init(id: String = UUID().uuidString, 
         name: String, 
         email: String, 
         phone: String, 
         licenseNumber: String, 
         hireDate: Date = Date(), 
         isActive: Bool = true,
         isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.licenseNumber = licenseNumber
        self.hireDate = hireDate
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.password = String(Int.random(in: 100000...999999)) // 6-digit random password
    }
} 