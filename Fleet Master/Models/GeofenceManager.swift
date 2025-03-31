import Foundation
import CoreLocation
import MapKit
import SwiftUI

class GeofenceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GeofenceManager()
    
    // Published properties for monitoring geofences
    @Published var monitoredGeofences: [Geofence] = []
    @Published var monitoredRegions: [String: CLCircularRegion] = [:]
    @Published var activeGeofenceEvents: [GeofenceEvent] = []
    @Published var isMonitoringActive = false
    
    // Limit to reasonable maximum number of monitored regions (iOS has a limit around 20)
    private let maxMonitoredRegions = 15
    
    // Reference to the notification manager for sending alerts
    private let notificationManager = NotificationManager.shared
    
    // Location manager for handling geofence monitoring
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization() // Required for background geofencing
        
        // Load saved geofences if available
        loadSavedGeofences()
    }
    
    // MARK: - Geofence Management
    
    func startMonitoring() {
        isMonitoringActive = true
        
        for geofence in monitoredGeofences {
            startMonitoring(geofence: geofence)
        }
    }
    
    func stopMonitoring() {
        isMonitoringActive = false
        
        // Remove all regions from monitoring
        for regionIdentifier in monitoredRegions.keys {
            if let region = monitoredRegions[regionIdentifier] {
                locationManager.stopMonitoring(for: region)
            }
        }
        
        monitoredRegions.removeAll()
    }
    
    func startMonitoring(geofence: Geofence) {
        guard isMonitoringActive,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return
        }
        
        // Check if we're already at the maximum number of regions
        if monitoredRegions.count >= maxMonitoredRegions {
            // If we're at max, we need to stop monitoring the oldest one
            if let oldestIdentifier = monitoredRegions.keys.first {
                if let oldestRegion = monitoredRegions[oldestIdentifier] {
                    locationManager.stopMonitoring(for: oldestRegion)
                }
                monitoredRegions.removeValue(forKey: oldestIdentifier)
            }
        }
        
        // Create a region to monitor
        let region = CLCircularRegion(
            center: geofence.coordinate,
            radius: geofence.radius,
            identifier: geofence.id
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Start monitoring the region
        locationManager.startMonitoring(for: region)
        monitoredRegions[geofence.id] = region
    }
    
    func stopMonitoring(geofence: Geofence) {
        if let region = monitoredRegions[geofence.id] {
            locationManager.stopMonitoring(for: region)
            monitoredRegions.removeValue(forKey: geofence.id)
        }
    }
    
    func addGeofence(name: String, coordinate: CLLocationCoordinate2D, radius: Double, tripIds: [String]) {
        let geofence = Geofence(
            id: UUID().uuidString,
            name: name,
            coordinate: coordinate,
            radius: radius,
            tripIds: tripIds,
            createdAt: Date()
        )
        
        monitoredGeofences.append(geofence)
        saveGeofences()
        
        if isMonitoringActive {
            startMonitoring(geofence: geofence)
        }
    }
    
    func updateGeofence(id: String, name: String? = nil, coordinate: CLLocationCoordinate2D? = nil, 
                        radius: Double? = nil, tripIds: [String]? = nil) {
        guard let index = monitoredGeofences.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Stop monitoring the old version
        stopMonitoring(geofence: monitoredGeofences[index])
        
        // Update the geofence with new values
        var updatedGeofence = monitoredGeofences[index]
        
        if let name = name {
            updatedGeofence.name = name
        }
        
        if let coordinate = coordinate {
            updatedGeofence.coordinate = coordinate
        }
        
        if let radius = radius {
            updatedGeofence.radius = radius
        }
        
        if let tripIds = tripIds {
            updatedGeofence.tripIds = tripIds
        }
        
        // Replace the old geofence with the updated one
        monitoredGeofences[index] = updatedGeofence
        saveGeofences()
        
        // Start monitoring the updated geofence
        if isMonitoringActive {
            startMonitoring(geofence: updatedGeofence)
        }
    }
    
    func removeGeofence(id: String) {
        guard let index = monitoredGeofences.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Stop monitoring this geofence
        stopMonitoring(geofence: monitoredGeofences[index])
        
        // Remove from the list
        monitoredGeofences.remove(at: index)
        saveGeofences()
    }
    
    // MARK: - Persistence
    
    private func saveGeofences() {
        // In a real app, this would save to UserDefaults, CoreData, or a backend API
        // For this demo, we'll just print a message
        print("Saving \(monitoredGeofences.count) geofences")
    }
    
    private func loadSavedGeofences() {
        // In a real app, this would load from storage
        // For this demo, we'll just use some example geofences
        
        // Clear existing geofences
        monitoredGeofences.removeAll()
        
        // Add some sample geofences for demonstration
        let sampleGeofences = [
            Geofence(
                id: "warehouse-zone",
                name: "Warehouse Zone",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radius: 500,
                tripIds: ["all"],
                createdAt: Date()
            ),
            Geofence(
                id: "delivery-zone",
                name: "Delivery Zone",
                coordinate: CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4300),
                radius: 300,
                tripIds: ["all"],
                createdAt: Date()
            )
        ]
        
        monitoredGeofences.append(contentsOf: sampleGeofences)
    }
    
    // MARK: - Utility Methods
    
    func checkVehicleInGeofences(vehicleId: String, location: CLLocation, tripId: String) {
        for geofence in monitoredGeofences {
            // Check if this geofence applies to this trip
            if geofence.tripIds.contains("all") || geofence.tripIds.contains(tripId) {
                let geofenceLocation = CLLocation(
                    latitude: geofence.coordinate.latitude,
                    longitude: geofence.coordinate.longitude
                )
                
                let distance = location.distance(from: geofenceLocation)
                let isInside = distance <= geofence.radius
                
                // Check for geofence entry/exit
                let eventType: GeofenceEventType = isInside ? .entry : .exit
                processGeofenceEvent(vehicleId: vehicleId, tripId: tripId, geofence: geofence, eventType: eventType)
            }
        }
    }
    
    private func processGeofenceEvent(vehicleId: String, tripId: String, geofence: Geofence, eventType: GeofenceEventType) {
        // Create a unique key for this vehicle-geofence combination
        let eventKey = "\(vehicleId)-\(geofence.id)"
        
        // Check if we already have an event for this combination
        if let existingEventIndex = activeGeofenceEvents.firstIndex(where: { $0.eventKey == eventKey }) {
            let existingEvent = activeGeofenceEvents[existingEventIndex]
            
            // Only process the event if it's different from the previous state
            if existingEvent.eventType != eventType {
                // Update the event
                let updatedEvent = GeofenceEvent(
                    eventKey: eventKey,
                    vehicleId: vehicleId,
                    tripId: tripId,
                    geofenceId: geofence.id,
                    geofenceName: geofence.name,
                    eventType: eventType,
                    timestamp: Date()
                )
                
                activeGeofenceEvents[existingEventIndex] = updatedEvent
                
                // Send notification
                notificationManager.sendGeofenceAlert(
                    tripId: tripId,
                    tripTitle: "Trip for \(vehicleId)", // In a real app, get the actual trip title
                    zoneName: geofence.name,
                    eventType: eventType
                )
            }
        } else {
            // This is a new event
            let newEvent = GeofenceEvent(
                eventKey: eventKey,
                vehicleId: vehicleId,
                tripId: tripId,
                geofenceId: geofence.id,
                geofenceName: geofence.name,
                eventType: eventType,
                timestamp: Date()
            )
            
            activeGeofenceEvents.append(newEvent)
            
            // Send notification
            notificationManager.sendGeofenceAlert(
                tripId: tripId,
                tripTitle: "Trip for \(vehicleId)", // In a real app, get the actual trip title
                zoneName: geofence.name,
                eventType: eventType
            )
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let geofence = monitoredGeofences.first(where: { $0.id == region.identifier }) {
            // In a real app, you would determine which vehicle triggered this
            // For this demo, we'll use a placeholder
            notificationManager.sendGeofenceAlert(
                tripId: "demo-trip",
                tripTitle: "Demo Trip",
                zoneName: geofence.name,
                eventType: .entry
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let geofence = monitoredGeofences.first(where: { $0.id == region.identifier }) {
            // In a real app, you would determine which vehicle triggered this
            // For this demo, we'll use a placeholder
            notificationManager.sendGeofenceAlert(
                tripId: "demo-trip",
                tripTitle: "Demo Trip",
                zoneName: geofence.name,
                eventType: .exit
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            // Restart monitoring if we got authorization
            if isMonitoringActive {
                stopMonitoring()
                startMonitoring()
            }
        }
    }
}

// Geofence data structure
struct Geofence: Identifiable, Equatable {
    let id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var radius: Double // in meters
    var tripIds: [String] // "all" or specific trip IDs
    let createdAt: Date
    
    static func == (lhs: Geofence, rhs: Geofence) -> Bool {
        return lhs.id == rhs.id
    }
}

// Geofence event data structure
struct GeofenceEvent: Identifiable {
    let id = UUID()
    let eventKey: String // vehicleId-geofenceId
    let vehicleId: String
    let tripId: String
    let geofenceId: String
    let geofenceName: String
    let eventType: GeofenceEventType
    let timestamp: Date
    
    // Formatted time for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
} 