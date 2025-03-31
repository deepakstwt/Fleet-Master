import Foundation
import CoreLocation
import MapKit
import SwiftUI

class RouteHistoryManager: ObservableObject {
    static let shared = RouteHistoryManager()
    
    @Published var vehicleHistories: [String: [VehicleHistoryPoint]] = [:]
    @Published var isRecordingHistory = false
    
    // Maximum number of history points to keep per vehicle
    private let maxHistoryPoints = 1000
    
    // Retain history for up to 24 hours
    private let maxHistoryAge: TimeInterval = 24 * 60 * 60
    
    private var historyTimer: Timer?
    
    init() {
        cleanupOldHistory()
    }
    
    // MARK: - Recording and Management
    
    func startRecordingHistory() {
        isRecordingHistory = true
        
        // Set up a timer to clean old history points periodically
        historyTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupOldHistory()
        }
    }
    
    func stopRecordingHistory() {
        isRecordingHistory = false
        historyTimer?.invalidate()
        historyTimer = nil
    }
    
    func recordVehiclePosition(vehicleId: String, location: CLLocation, tripId: String, status: TripStatus) {
        guard isRecordingHistory else { return }
        
        let historyPoint = VehicleHistoryPoint(
            coordinate: location.coordinate,
            timestamp: Date(),
            speed: location.speed > 0 ? location.speed : nil,
            heading: location.course >= 0 ? location.course : nil,
            tripId: tripId,
            status: status
        )
        
        DispatchQueue.main.async {
            // Initialize array if this is first point for vehicle
            if self.vehicleHistories[vehicleId] == nil {
                self.vehicleHistories[vehicleId] = []
            }
            
            // Add the new point
            self.vehicleHistories[vehicleId]?.append(historyPoint)
            
            // Ensure we don't exceed max history points
            if let count = self.vehicleHistories[vehicleId]?.count, count > self.maxHistoryPoints {
                self.vehicleHistories[vehicleId]?.removeFirst(count - self.maxHistoryPoints)
            }
        }
    }
    
    func clearHistoryForVehicle(vehicleId: String) {
        DispatchQueue.main.async {
            self.vehicleHistories[vehicleId] = []
        }
    }
    
    func clearAllHistory() {
        DispatchQueue.main.async {
            self.vehicleHistories.removeAll()
        }
    }
    
    private func cleanupOldHistory() {
        let cutoffTime = Date().addingTimeInterval(-maxHistoryAge)
        
        DispatchQueue.main.async {
            // For each vehicle, remove history points older than cutoff
            for vehicleId in self.vehicleHistories.keys {
                self.vehicleHistories[vehicleId]?.removeAll { $0.timestamp < cutoffTime }
            }
            
            // Remove any empty vehicle histories
            self.vehicleHistories = self.vehicleHistories.filter { !$0.value.isEmpty }
        }
    }
    
    // MARK: - Data Access
    
    func getHistoryForVehicle(vehicleId: String) -> [VehicleHistoryPoint] {
        return vehicleHistories[vehicleId] ?? []
    }
    
    func getHistoryForVehicle(vehicleId: String, from: Date, to: Date) -> [VehicleHistoryPoint] {
        let allHistory = vehicleHistories[vehicleId] ?? []
        return allHistory.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
    
    func getHistoryForTrip(tripId: String) -> [VehicleHistoryPoint] {
        // Search across all vehicles for points matching this trip
        var tripHistory: [VehicleHistoryPoint] = []
        
        for vehicleHistory in vehicleHistories.values {
            let points = vehicleHistory.filter { $0.tripId == tripId }
            tripHistory.append(contentsOf: points)
        }
        
        // Sort by timestamp
        return tripHistory.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Visualization Helper Methods
    
    func createHistoryPolyline(for vehicleId: String, timeframe: HistoryTimeframe = .today) -> MKPolyline? {
        let historyPoints = filteredHistoryPoints(for: vehicleId, timeframe: timeframe)
        
        guard !historyPoints.isEmpty else { return nil }
        
        // Convert history points to coordinates
        let coordinates = historyPoints.map { $0.coordinate }
        
        // Create polyline
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    func filteredHistoryPoints(for vehicleId: String, timeframe: HistoryTimeframe) -> [VehicleHistoryPoint] {
        let history = vehicleHistories[vehicleId] ?? []
        
        // Apply time filtering based on timeframe
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case .lastHour:
            let oneHourAgo = now.addingTimeInterval(-3600)
            return history.filter { $0.timestamp >= oneHourAgo }
            
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return history.filter { $0.timestamp >= startOfDay }
            
        case .yesterday:
            let startOfYesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
            let endOfYesterday = calendar.startOfDay(for: now)
            return history.filter { $0.timestamp >= startOfYesterday && $0.timestamp < endOfYesterday }
            
        case .lastWeek:
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return history.filter { $0.timestamp >= oneWeekAgo }
            
        case .all:
            return history
        }
    }
}

// History point for a vehicle
struct VehicleHistoryPoint: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let speed: Double?  // in m/s, nil if unknown
    let heading: Double? // in degrees, nil if unknown
    let tripId: String
    let status: TripStatus
    
    // Computed property for formatted timestamp
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
    
    // For Equatable
    static func == (lhs: VehicleHistoryPoint, rhs: VehicleHistoryPoint) -> Bool {
        return lhs.id == rhs.id
    }
}

// Timeframe options for history filtering
enum HistoryTimeframe: String, CaseIterable {
    case lastHour = "Last Hour"
    case today = "Today"
    case yesterday = "Yesterday"
    case lastWeek = "Last Week"
    case all = "All History"
    
    var displayName: String {
        return self.rawValue
    }
    
    // Keep this for compatibility, but make it return English names
    var hindiName: String {
        return self.rawValue
    }
} 