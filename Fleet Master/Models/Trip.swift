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
    
    // MARK: - CodingKeys for Supabase mapping
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startLocation = "startLocation"
        case endLocation = "endLocation"
        case scheduledStartTime = "scheduledStartTime"
        case scheduledEndTime = "scheduledEndTime"
        case description
        case status
        case driverId = "driver_id"
        case vehicleId = "vehicleId"
        case distance
        case actualStartTime = "actualStartTime"
        case actualEndTime = "actualEndTime"
        case notes
        case routeInfo = "routeInfo"
    }
    
    // MARK: - Custom initializer for decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode ID with special handling for UUID strings
        if let uuidString = try? container.decode(String.self, forKey: .id) {
            id = uuidString
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Unable to decode ID")
        }
        
        // Decode basic properties
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        startLocation = try container.decodeIfPresent(String.self, forKey: .startLocation) ?? ""
        endLocation = try container.decodeIfPresent(String.self, forKey: .endLocation) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        driverId = try container.decodeIfPresent(String.self, forKey: .driverId)
        vehicleId = try container.decodeIfPresent(String.self, forKey: .vehicleId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Decode numeric value
        if let distanceString = try? container.decode(String.self, forKey: .distance) {
            distance = Double(distanceString)
        } else {
            distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        }
        
        // Decode status with error handling
        if let statusString = try? container.decode(String.self, forKey: .status),
           let parsedStatus = TripStatus(rawValue: statusString) {
            status = parsedStatus
        } else {
            status = .scheduled
        }
        
        // Decode dates with ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Scheduled dates (required)
        if let startTimeString = try? container.decode(String.self, forKey: .scheduledStartTime) {
            scheduledStartTime = dateFormatter.date(from: startTimeString) ?? Date()
        } else {
            scheduledStartTime = try container.decodeIfPresent(Date.self, forKey: .scheduledStartTime) ?? Date()
        }
        
        if let endTimeString = try? container.decode(String.self, forKey: .scheduledEndTime) {
            scheduledEndTime = dateFormatter.date(from: endTimeString) ?? Date().addingTimeInterval(3600)
        } else {
            scheduledEndTime = try container.decodeIfPresent(Date.self, forKey: .scheduledEndTime) ?? Date().addingTimeInterval(3600)
        }
        
        // Optional dates
        if let actualStartTimeString = try? container.decode(String.self, forKey: .actualStartTime) {
            actualStartTime = dateFormatter.date(from: actualStartTimeString)
        } else {
            actualStartTime = try? container.decode(Date.self, forKey: .actualStartTime)
        }
        
        if let actualEndTimeString = try? container.decode(String.self, forKey: .actualEndTime) {
            actualEndTime = dateFormatter.date(from: actualEndTimeString)
        } else {
            actualEndTime = try? container.decode(Date.self, forKey: .actualEndTime)
        }
        
        // Decode route info if present
        routeInfo = try container.decodeIfPresent(RouteInformation.self, forKey: .routeInfo)
    }
    
    // MARK: - Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode basic properties
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startLocation, forKey: .startLocation)
        try container.encode(endLocation, forKey: .endLocation)
        try container.encode(description, forKey: .description)
        try container.encode(status.rawValue, forKey: .status)
        
        // Encode optional properties
        try container.encodeIfPresent(driverId, forKey: .driverId)
        try container.encodeIfPresent(vehicleId, forKey: .vehicleId)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(notes, forKey: .notes)
        
        // Format dates to ISO8601 for Supabase
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Encode dates as ISO8601 strings
        try container.encode(dateFormatter.string(from: scheduledStartTime), forKey: .scheduledStartTime)
        try container.encode(dateFormatter.string(from: scheduledEndTime), forKey: .scheduledEndTime)
        
        // Optional dates
        if let actualStartTime = actualStartTime {
            try container.encode(dateFormatter.string(from: actualStartTime), forKey: .actualStartTime)
        }
        
        if let actualEndTime = actualEndTime {
            try container.encode(dateFormatter.string(from: actualEndTime), forKey: .actualEndTime)
        }
        
        // Encode route info if present
        try container.encodeIfPresent(routeInfo, forKey: .routeInfo)
    }
    
    // MARK: - Regular initializer
    
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
    case scheduled = "scheduled"
    case inProgress = "ongoing"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct RouteInformation: Equatable, Codable {
    let distance: Double
    let time: TimeInterval
    
    static func == (lhs: RouteInformation, rhs: RouteInformation) -> Bool {
        return lhs.distance == rhs.distance && lhs.time == rhs.time
    }
} 
