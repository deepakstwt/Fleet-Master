import Foundation

struct MaintenanceVehicle: Codable, Identifiable {
    let id: UUID
    var ticketNo: String
    let registrationNumber: String
    let problem: String
    let priority: Priority
    let maintenanceNote: String
    let type: MaintenanceType
    let assignedPersonnelId: String
    let completed: Bool
    let cost: Float
    let status: MaintenanceStatus
    let accepted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticketNo = "ticketNo"
        case registrationNumber = "registration_number"
        case problem = "problem"
        case priority = "priority"
        case maintenanceNote = "maintenance_Note"
        case type = "type"
        case assignedPersonnelId = "assigned_Personnel_id"
        case completed = "completed"
        case cost = "cost"
        case status = "status"
        case accepted = "accepted"
    }
    
    enum Priority: String, Codable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    enum MaintenanceType: String, Codable {
        case routine = "Maintenance"
        case repair = "Repair"
    }
    
    enum MaintenanceStatus: String, Codable {
        case active = "Active"
        case schedule = "Schedule"
            }
    
    init(id: UUID, ticketNo: String, registrationNumber: String, problem: String, priority: Priority, maintenanceNote: String, type: MaintenanceType, assignedPersonnelId: String) {
        self.id = id
        self.ticketNo = ticketNo
        self.registrationNumber = registrationNumber
        self.problem = problem
        self.priority = priority
        self.maintenanceNote = maintenanceNote
        self.type = type
        self.assignedPersonnelId = assignedPersonnelId
        // Default values for maintenance app managed fields
        self.completed = false
        self.cost = 0.0
        self.status = .schedule
        self.accepted = false
    }
} 
