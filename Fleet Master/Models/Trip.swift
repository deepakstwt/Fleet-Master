import Foundation

struct Trip: Identifiable, Codable, Hashable, Equatable {
    var id: String
    var title: String
    var startLocation: String
    var endLocation: String
    var scheduledStartTime: Date
    var scheduledEndTime: Date
    var status: TripStatus
    var driverId: String?
    var vehicleId: String?
    var description: String
    var distance: Double?
    var actualStartTime: Date?
    var actualEndTime: Date?
    var notes: String?
    var routeInfo: RouteInformation?
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.id == rhs.id
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         startLocation: String,
         endLocation: String,
         scheduledStartTime: Date,
         scheduledEndTime: Date,
         status: TripStatus = .scheduled,
         driverId: String? = nil,
         vehicleId: String? = nil,
         description: String,
         distance: Double? = nil,
         actualStartTime: Date? = nil,
         actualEndTime: Date? = nil,
         notes: String? = nil,
         routeInfo: RouteInformation? = nil) {
        self.id = id
        self.title = title
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.scheduledStartTime = scheduledStartTime
        self.scheduledEndTime = scheduledEndTime
        self.status = status
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.description = description
        self.distance = distance
        self.actualStartTime = actualStartTime
        self.actualEndTime = actualEndTime
        self.notes = notes
        self.routeInfo = routeInfo
    }
    
    // MARK: - Preview Helpers
    
    static var previewTrip: Trip {
        let calendar = Calendar.current
        let startTime = calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let endTime = calendar.date(byAdding: .hour, value: 5, to: startTime) ?? Date()
        
        return Trip(
            id: "preview-trip-1",
            title: "Delivery to Downtown Office",
            startLocation: "Warehouse District",
            endLocation: "Financial District",
            scheduledStartTime: startTime,
            scheduledEndTime: endTime,
            status: .scheduled,
            driverId: "driver-1",
            vehicleId: "vehicle-1",
            description: "Regular delivery of office supplies to the headquarters",
            distance: 15.2,
            notes: "Parking available in the underground garage. Ask for John at reception."
        )
    }
}

enum TripStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

struct RouteInformation: Equatable, Codable {
    let distance: Double
    let time: TimeInterval
    
    static func == (lhs: RouteInformation, rhs: RouteInformation) -> Bool {
        return lhs.distance == rhs.distance && lhs.time == rhs.time
    }
} 