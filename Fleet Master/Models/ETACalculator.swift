import Foundation
import CoreLocation
import MapKit
import SwiftUI

class ETACalculator: ObservableObject {
    static let shared = ETACalculator()
    
    // Published properties
    @Published var tripETAs: [String: ETAInfo] = [:]
    @Published var isFetchingTrafficData = false
    
    // Default traffic speed factor (1.0 = nominal speed with no traffic)
    @Published var trafficSpeedFactor: Double = 1.0
    
    // Simulated traffic conditions for demo
    private var simulatedTrafficConditions: [TrafficCondition] = []
    
    // Timer for periodic ETA updates
    private var etaUpdateTimer: Timer?
    
    // The update interval in seconds
    private let updateInterval: TimeInterval = 60.0
    
    init() {
        // Set up simulated traffic conditions for demo
        setupSimulatedTrafficConditions()
    }
    
    // MARK: - ETA Calculation Methods
    
    func startETAUpdates() {
        // Start a timer for periodic ETA updates
        etaUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateTrafficConditions()
            self?.recalculateAllETAs()
        }
        
        // Fire timer immediately to get initial ETAs
        updateTrafficConditions()
    }
    
    func stopETAUpdates() {
        etaUpdateTimer?.invalidate()
        etaUpdateTimer = nil
    }
    
    func calculateETA(for trip: Trip, vehicleLocation: CLLocation) {
        // In a real app, you would use a mapping/routing service to get ETA with traffic
        // For this demo, we'll simulate it
        
        // Mark as loading
        isFetchingTrafficData = true
        
        // Get the destination location
        getDestinationCoordinate(for: trip) { [weak self] destinationCoordinate in
            guard let self = self, let destinationCoordinate = destinationCoordinate else {
                self?.isFetchingTrafficData = false
                return
            }
            
            // Calculate base ETA (without traffic)
            let destinationLocation = CLLocation(
                latitude: destinationCoordinate.latitude,
                longitude: destinationCoordinate.longitude
            )
            
            // Distance in meters
            let distance = vehicleLocation.distance(from: destinationLocation)
            
            // Calculate the base ETA (assuming average speed of 50 km/h = 13.89 m/s)
            let baseAverageSpeedMPS = 13.89
            
            // Apply traffic factor to speed (slower in heavy traffic)
            let adjustedSpeed = baseAverageSpeedMPS * self.trafficSpeedFactor
            
            // Calculate ETA in seconds
            let etaSeconds = distance / adjustedSpeed
            
            // Expected arrival time
            let expectedArrivalTime = Date().addingTimeInterval(etaSeconds)
            
            // Calculate delay compared to scheduled arrival
            var delayInMinutes = 0
            let scheduledArrival = trip.scheduledEndTime
            if scheduledArrival != nil {
                let delayInSeconds = expectedArrivalTime.timeIntervalSince(scheduledArrival)
                delayInMinutes = max(0, Int(delayInSeconds / 60.0))
            }
            
            // Traffic condition at the destination
            let trafficLevel = self.getTrafficLevelForLocation(destinationCoordinate)
            
            // Create ETA info
            let etaInfo = ETAInfo(
                tripId: trip.id,
                expectedArrivalTime: expectedArrivalTime,
                remainingDistance: distance,
                trafficCondition: trafficLevel,
                delayMinutes: delayInMinutes,
                lastUpdated: Date()
            )
            
            // Update the ETA info
            DispatchQueue.main.async {
                self.tripETAs[trip.id] = etaInfo
                self.isFetchingTrafficData = false
            }
        }
    }
    
    func recalculateAllETAs() {
        // For all trips with ETAs, recalculate
        for tripId in tripETAs.keys {
            // In a real app, you would look up the trip and vehicle data
            // For this demo, we'll simulate by slightly adjusting the existing ETA
            if var etaInfo = tripETAs[tripId] {
                // Adjust the ETA randomly to simulate changing traffic conditions
                let randomAdjustment = Double.random(in: -180...120) // -3 to +2 minutes
                let newArrivalTime = etaInfo.expectedArrivalTime.addingTimeInterval(randomAdjustment)
                
                // Randomly adjust traffic condition
                let newTrafficCondition = randomTrafficCondition()
                
                // Update the ETA info
                etaInfo.expectedArrivalTime = newArrivalTime
                etaInfo.trafficCondition = newTrafficCondition
                etaInfo.lastUpdated = Date()
                
                // Recalculate delay minutes
                let trip = findTripById(tripId)
                if trip != nil, trip!.scheduledEndTime != nil {
                    let scheduledArrival = trip!.scheduledEndTime
                    let delayInSeconds = newArrivalTime.timeIntervalSince(scheduledArrival)
                    etaInfo.delayMinutes = max(0, Int(delayInSeconds / 60.0))
                }
                
                // Update in the map
                DispatchQueue.main.async {
                    self.tripETAs[tripId] = etaInfo
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDestinationCoordinate(for trip: Trip, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // In a real app, you would geocode the address
        // For this demo, we'll simulate with a random location
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(trip.endLocation) { placemarks, error in
            if let error = error {
                print("Error geocoding destination: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first, let location = placemark.location {
                completion(location.coordinate)
            } else {
                // Fallback to a random location if geocoding fails
                let baseLatitude = 37.7749
                let baseLongitude = -122.4194
                let randomLat = baseLatitude + Double.random(in: -0.05...0.05)
                let randomLng = baseLongitude + Double.random(in: -0.05...0.05)
                
                completion(CLLocationCoordinate2D(latitude: randomLat, longitude: randomLng))
            }
        }
    }
    
    private func findTripById(_ tripId: String) -> Trip? {
        // In a real app, you would query your database or trip store
        // For this demo, we'll return a dummy trip
        
        let now = Date()
        let later = now.addingTimeInterval(3600) // 1 hour later
        
        return Trip(
            id: tripId,
            title: "Trip \(tripId)",
            startLocation: "Start Location",
            endLocation: "End Location",
            scheduledStartTime: now,
            scheduledEndTime: later,
            description: "Demo trip"
        )
    }
    
    // MARK: - Traffic Simulation
    
    private func setupSimulatedTrafficConditions() {
        // Create simulated traffic conditions for various areas
        simulatedTrafficConditions = [
            TrafficCondition(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radius: 5000,
                level: .heavy
            ),
            TrafficCondition(
                coordinate: CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4300),
                radius: 3000,
                level: .moderate
            ),
            TrafficCondition(
                coordinate: CLLocationCoordinate2D(latitude: 37.7650, longitude: -122.4050),
                radius: 2000,
                level: .light
            )
        ]
    }
    
    private func updateTrafficConditions() {
        // Randomly update the traffic conditions to simulate changing traffic
        for i in 0..<simulatedTrafficConditions.count {
            // Randomly change the traffic level
            if Double.random(in: 0...1) < 0.3 { // 30% chance to change
                simulatedTrafficConditions[i].level = randomTrafficLevel()
            }
        }
        
        // Update global traffic speed factor
        updateTrafficSpeedFactor()
    }
    
    private func updateTrafficSpeedFactor() {
        // Calculate an overall traffic speed factor based on the conditions
        let trafficLevels = simulatedTrafficConditions.map { $0.level }
        
        // Count occurrences of each level
        let heavyCount = trafficLevels.filter { $0 == .heavy }.count
        let moderateCount = trafficLevels.filter { $0 == .moderate }.count
        let lightCount = trafficLevels.filter { $0 == .light }.count
        
        // Break up the complex expression to improve compile time
        // Heavy = 0.5x speed, Moderate = 0.8x speed, Light = 1.0x speed
        let heavyValue = Double(heavyCount) * 0.5
        let moderateValue = Double(moderateCount) * 0.8
        let lightValue = Double(lightCount) * 1.0
        
        let totalWeight = heavyCount + moderateCount + lightCount
        let weightedSum = heavyValue + moderateValue + lightValue
        
        // Calculate the new speed factor, default to 0.9 if no traffic data
        let newSpeedFactor: Double
        if totalWeight > 0 {
            newSpeedFactor = weightedSum / Double(totalWeight)
        } else {
            newSpeedFactor = 0.9
        }
        
        // Add some randomness
        let randomFactor = Double.random(in: 0.9...1.1)
        trafficSpeedFactor = newSpeedFactor * randomFactor
    }
    
    private func getTrafficLevelForLocation(_ coordinate: CLLocationCoordinate2D) -> TrafficLevel {
        // Find the traffic condition that applies to this location
        for condition in simulatedTrafficConditions {
            let conditionLocation = CLLocation(
                latitude: condition.coordinate.latitude,
                longitude: condition.coordinate.longitude
            )
            
            let locationToCheck = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            let distance = locationToCheck.distance(from: conditionLocation)
            
            if distance <= condition.radius {
                return condition.level
            }
        }
        
        // Default to moderate if not in any specific zone
        return .moderate
    }
    
    private func randomTrafficLevel() -> TrafficLevel {
        let random = Int.random(in: 0...2)
        switch random {
        case 0: return .light
        case 1: return .moderate
        case 2: return .heavy
        default: return .moderate
        }
    }
    
    private func randomTrafficCondition() -> TrafficLevel {
        // Weighted random - more likely to be moderate
        let random = Double.random(in: 0...1)
        if random < 0.2 {
            return .light
        } else if random < 0.7 {
            return .moderate
        } else {
            return .heavy
        }
    }
}

// MARK: - Supporting Types

struct ETAInfo: Equatable {
    let tripId: String
    var expectedArrivalTime: Date
    var remainingDistance: Double
    var trafficCondition: TrafficLevel
    var delayMinutes: Int
    var lastUpdated: Date
    
    // Formatted ETA for display
    var formattedETA: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: expectedArrivalTime)
    }
    
    // Formatted remaining distance for display
    var formattedDistance: String {
        if remainingDistance >= 1000 {
            return String(format: "%.1f km", remainingDistance / 1000)
        } else {
            return "\(Int(remainingDistance)) m"
        }
    }
    
    static func == (lhs: ETAInfo, rhs: ETAInfo) -> Bool {
        return lhs.tripId == rhs.tripId &&
               lhs.expectedArrivalTime == rhs.expectedArrivalTime &&
               lhs.remainingDistance == rhs.remainingDistance &&
               lhs.trafficCondition == rhs.trafficCondition &&
               lhs.delayMinutes == rhs.delayMinutes
    }
}

struct TrafficCondition {
    var coordinate: CLLocationCoordinate2D
    var radius: Double // meters
    var level: TrafficLevel
}

enum TrafficLevel: String, CaseIterable {
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        }
    }
    
    // Keep this for compatibility, but make it return English names
    var hindiName: String {
        return self.displayName
    }
    
    var color: Color {
        switch self {
        case .light: return .green
        case .moderate: return .orange
        case .heavy: return .red
        }
    }
    
    var speedFactor: Double {
        switch self {
        case .light: return 1.0
        case .moderate: return 0.8
        case .heavy: return 0.5
        }
    }
}

class MapSearch: NSObject, ObservableObject {
    @Published var locationResults: [MKLocalSearchCompletion] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var recentSearches: [String] = []
    
    private var completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        if let saved = UserDefaults.standard.stringArray(forKey: "recentLocationSearches") {
            recentSearches = saved
        }
    }
    
    func update(queryFragment: String) {
        isLoading = true
        errorMessage = nil
        
        if queryFragment.isEmpty {
            locationResults = []
            isLoading = false
            return
        }
        
        completer.queryFragment = queryFragment
    }
    
    func saveRecentSearch(_ search: String) {
        if !recentSearches.contains(search) {
            recentSearches.insert(search, at: 0)
            
            if recentSearches.count > 5 {
                recentSearches = Array(recentSearches.prefix(5))
            }
            
            UserDefaults.standard.set(recentSearches, forKey: "recentLocationSearches")
        }
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recentLocationSearches")
    }
}

extension MapSearch: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.locationResults = completer.results
            self?.isLoading = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Search error: \(error.localizedDescription)"
            self?.isLoading = false
        }
    }
} 