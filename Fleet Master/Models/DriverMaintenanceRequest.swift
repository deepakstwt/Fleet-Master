import Foundation
import SwiftUI

/// Model representing a maintenance request submitted by a driver
struct DriverMaintenanceRequest: Identifiable, Codable {
    let id: String
    let createdAt: Date
    let problem: String
    let priority: PriorityForMaintainence
    let maintenanceNote: String?
    let accepted: Bool
    let type: String
    let completed: Bool
    let cost: Int?
    let assignedPersonnelId: String?
    let status: String
    let ticketNo: String?
    let registrationNumber: String
    let driverAssigned: String
    let scheduleDate: Date?
    let scheduleTime: String?
    let vehicleId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case problem
        case priority
        case maintenanceNote = "maintenance_Note"
        case accepted
        case type
        case completed
        case cost
        case assignedPersonnelId = "assigned_Personnel_id"
        case status
        case ticketNo
        case registrationNumber = "registration_number"
        case driverAssigned = "driverAssigned"
        case scheduleDate = "schedule_Date"
        case scheduleTime = "schedule_Time"
        case vehicleId = "vehicle_id"
    }
    
    // Custom initializer for decoding to handle ISO dates from Supabase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic properties
        id = try container.decode(String.self, forKey: .id)
        problem = try container.decode(String.self, forKey: .problem)
        priority = try container.decode(PriorityForMaintainence.self, forKey: .priority)
        maintenanceNote = try container.decodeIfPresent(String.self, forKey: .maintenanceNote)
        accepted = try container.decode(Bool.self, forKey: .accepted)
        type = try container.decode(String.self, forKey: .type)
        completed = try container.decode(Bool.self, forKey: .completed)
        cost = try container.decodeIfPresent(Int.self, forKey: .cost)
        assignedPersonnelId = try container.decodeIfPresent(String.self, forKey: .assignedPersonnelId)
        status = try container.decode(String.self, forKey: .status)
        ticketNo = try container.decodeIfPresent(String.self, forKey: .ticketNo)
        registrationNumber = try container.decode(String.self, forKey: .registrationNumber)
        driverAssigned = try container.decode(String.self, forKey: .driverAssigned)
        scheduleTime = try container.decodeIfPresent(String.self, forKey: .scheduleTime)
        vehicleId = try container.decode(String.self, forKey: .vehicleId)
        
        // Decode dates with ISO 8601 formatter
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let scheduleDateString = try? container.decodeIfPresent(String.self, forKey: .scheduleDate) {
            scheduleDate = scheduleDateString != nil ? dateFormatter.date(from: scheduleDateString) : nil
        } else {
            scheduleDate = try container.decodeIfPresent(Date.self, forKey: .scheduleDate)
        }
    }
}

enum PriorityForMaintainence: String, Codable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .yellow
        case .low:
            return .green
        }
    }
} 
