import Foundation
import CoreLocation
import MapKit
import SwiftUI

// Add a struct for vehicle location that includes heading
struct VehicleLocationInfo {
    let coordinate: CLLocationCoordinate2D
    let heading: Double
    let speed: Double
    let timestamp: Date
    
    init(coordinate: CLLocationCoordinate2D, heading: Double = 0.0, speed: Double = 0.0, timestamp: Date = Date()) {
        self.coordinate = coordinate
        self.heading = heading
        self.speed = speed
        self.timestamp = timestamp
    }
    
    var asLocation: CLLocation {
        return CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, course: heading, speed: speed, timestamp: timestamp)
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var location: CLLocation?
    @Published var isLoadingLocation = false
    
    // Update vehicle tracking to use VehicleLocationInfo
    @Published var vehicleLocations: [String: VehicleLocationInfo] = [:]
    @Published var trackedVehicles: Set<String> = []
    @Published var lastVehicleUpdateTime: [String: Date] = [:]
    @Published var isTrackingVehicles = false
    
    // Add new properties for route monitoring
    @Published var vehicleRouteDeviations: [String: Double] = [:]
    @Published var monitoredRoutes: [String: MKRoute] = [:]
    
    // Add reference to route history manager
    private let routeHistoryManager = RouteHistoryManager.shared
    
    // Add reference to geofence manager
    private let geofenceManager = GeofenceManager.shared
    
    // Add reference to ETA calculator
    private let etaCalculator = ETACalculator.shared
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            isLoadingLocation = true
            locationManager.requestLocation()
            
            if let location = lastLocation {
                continuation.resume(returning: location)
                isLoadingLocation = false
            } else {
                // We'll handle this in the delegate
                Task { @MainActor in
                    // Set up a timeout
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    if isLoadingLocation {
                        isLoadingLocation = false
                        continuation.resume(throwing: LocationError.locationNotFound)
                    }
                }
            }
        }
    }
    
    func startUpdatingLocation() {
        isLoadingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
    }
    
    // MARK: - Geocoding
    
    func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                completion(.failure(NSError(domain: "LocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to geocode address"])))
                return
            }
            
            completion(.success(location.coordinate))
        }
    }
    
    func reverseLookupLocation(_ coordinate: CLLocationCoordinate2D, completion: @escaping (Result<String, Error>) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(.failure(NSError(domain: "LocationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No placemark found"])))
                return
            }
            
            let address = [
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
            
            completion(.success(address))
        }
    }
    
    // MARK: - Route Calculation
    
    func calculateRoute(from startAddress: String, to endAddress: String, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        // First geocode the start address
        geocodeAddress(startAddress) { [weak self] startResult in
            guard let self = self else { return }
            
            switch startResult {
            case .success(let startCoordinate):
                // Then geocode the end address
                self.geocodeAddress(endAddress) { endResult in
                    switch endResult {
                    case .success(let endCoordinate):
                        // Create source and destination placemarks
                        let sourcePlacemark = MKPlacemark(coordinate: startCoordinate)
                        let destinationPlacemark = MKPlacemark(coordinate: endCoordinate)
                        
                        // Create routing request
                        let request = MKDirections.Request()
                        request.source = MKMapItem(placemark: sourcePlacemark)
                        request.destination = MKMapItem(placemark: destinationPlacemark)
                        request.transportType = .automobile
                        
                        // Calculate route
                        let directions = MKDirections(request: request)
                        directions.calculate { response, error in
                            if let error = error {
                                completion(.failure(error))
                                return
                            }
                            
                            guard let route = response?.routes.first else {
                                completion(.failure(NSError(domain: "LocationManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No route found"])))
                                return
                            }
                            
                            completion(.success(route))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Vehicle Tracking
    
    func startTrackingVehicles(vehicleIds: [String]) {
        isTrackingVehicles = true
        for vehicleId in vehicleIds {
            trackedVehicles.insert(vehicleId)
        }
        
        // Start recording history
        routeHistoryManager.startRecordingHistory()
        
        // Start geofence monitoring
        geofenceManager.startMonitoring()
        
        // Start ETA updates
        etaCalculator.startETAUpdates()
        
        // In a real app, this would connect to a backend service
        // For demonstration, we'll simulate vehicle movement
        startSimulatedVehicleUpdates()
    }
    
    func stopTrackingVehicles() {
        isTrackingVehicles = false
        trackedVehicles.removeAll()
        
        // Stop recording history
        routeHistoryManager.stopRecordingHistory()
        
        // Stop geofence monitoring
        geofenceManager.stopMonitoring()
        
        // Stop ETA updates
        etaCalculator.stopETAUpdates()
        
        // Stop any background tasks for tracking
    }
    
    private func startSimulatedVehicleUpdates() {
        // This is a simulation - in a real app, you would connect to your backend 
        // which would stream real GPS coordinates from driver devices
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isTrackingVehicles else {
                timer.invalidate()
                return
            }
            
            for vehicleId in self.trackedVehicles {
                // Simulate vehicle movement
                self.updateVehicleLocation(vehicleId: vehicleId)
            }
        }
    }
    
    private func updateVehicleLocation(vehicleId: String) {
        // In a real app, this would fetch data from your backend API
        // For demo purposes, we'll simulate random movement along a route
        
        if let existingLocation = vehicleLocations[vehicleId] {
            // Simulate movement by slightly adjusting coordinates
            let newLat = existingLocation.coordinate.latitude + (Double.random(in: -0.001...0.001))
            let newLng = existingLocation.coordinate.longitude + (Double.random(in: -0.001...0.001))
            let newLocation = CLLocation(latitude: newLat, longitude: newLng)
            
            vehicleLocations[vehicleId] = VehicleLocationInfo(coordinate: newLocation.coordinate, heading: newLocation.course, speed: newLocation.speed, timestamp: newLocation.timestamp)
            lastVehicleUpdateTime[vehicleId] = Date()
            
            // Find the trip that this vehicle is assigned to
            if let trip = findTripForVehicle(vehicleId: vehicleId) {
                // Record position in history
                routeHistoryManager.recordVehiclePosition(
                    vehicleId: vehicleId,
                    location: newLocation,
                    tripId: trip.id,
                    status: trip.status
                )
                
                // Check for geofence events
                geofenceManager.checkVehicleInGeofences(
                    vehicleId: vehicleId,
                    location: newLocation,
                    tripId: trip.id
                )
                
                // Update ETA for this vehicle's trip
                etaCalculator.calculateETA(for: trip, vehicleLocation: newLocation)
            }
        } else {
            // Initialize with a random position along one of the existing trip routes
            // In a real app, this would be the driver's actual GPS position
            let startLat = 37.7749 + (Double.random(in: -0.02...0.02))
            let startLng = -122.4194 + (Double.random(in: -0.02...0.02))
            let initialLocation = CLLocation(latitude: startLat, longitude: startLng)
            
            vehicleLocations[vehicleId] = VehicleLocationInfo(coordinate: initialLocation.coordinate, heading: initialLocation.course, speed: initialLocation.speed, timestamp: initialLocation.timestamp)
            lastVehicleUpdateTime[vehicleId] = Date()
        }
    }
    
    // Helper method to find the trip a vehicle is assigned to
    private func findTripForVehicle(vehicleId: String) -> Trip? {
        // In a real app, this would query your data model or backend
        // For demo purposes, we'll create a simple placeholder trip
        
        // In a production app, we would query a shared trip store or database
        // For this demo, we'll just create a placeholder trip when needed
        if vehicleLocations[vehicleId] != nil {
            // Create a simulated trip for this vehicle
            let now = Date()
            let later = now.addingTimeInterval(3600) // 1 hour later
            
            return Trip(
                id: "trip-\(vehicleId)",
                title: "Trip for Vehicle \(vehicleId)",
                startLocation: "Starting Point",
                endLocation: "Destination",
                scheduledStartTime: now,
                scheduledEndTime: later,
                status: .inProgress,
                vehicleId: vehicleId,
                description: "Simulated trip for tracking demo"
            )
        }
        
        return nil
    }
    
    func getVehicleLocation(vehicleId: String) -> CLLocation? {
        return vehicleLocations[vehicleId]?.asLocation
    }
    
    func isVehicleLocationRecent(vehicleId: String) -> Bool {
        guard let lastUpdate = lastVehicleUpdateTime[vehicleId] else {
            return false
        }
        
        // Consider updates within the last 30 seconds as "recent"
        return Date().timeIntervalSince(lastUpdate) < 30
    }
    
    // In a real implementation, this would connect to your backend API
    func fetchRealTimeGPSData(for vehicleId: String, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        // In a real app, fetch from API
        // For demo, we'll just return the simulated location
        
        if let location = vehicleLocations[vehicleId]?.asLocation {
            completion(.success(location))
        } else {
            let error = NSError(domain: "LocationManager", code: 4, 
                                userInfo: [NSLocalizedDescriptionKey: "Vehicle location not available"])
            completion(.failure(error))
        }
    }
    
    // MARK: - Route Monitoring
    
    func startMonitoringRouteDeviations(for trip: Trip, route: MKRoute) {
        guard let vehicleId = trip.vehicleId else { return }
        monitoredRoutes[vehicleId] = route
        
        // Start checking for route deviations periodically
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isTrackingVehicles else {
                timer.invalidate()
                return
            }
            
            self.checkForRouteDeviations(for: trip, route: route)
        }
    }
    
    func checkForRouteDeviations(for trip: Trip, route: MKRoute) {
        guard let vehicleId = trip.vehicleId,
              let vehicleLocation = vehicleLocations[vehicleId] else {
            return
        }
        
        // Calculate distance from vehicle's current location to the route
        let distanceFromRoute = distanceFromRoute(location: vehicleLocation.coordinate, route: route)
        vehicleRouteDeviations[vehicleId] = distanceFromRoute
        
        // Check if vehicle is off route beyond threshold
        let offRouteThreshold = NotificationManager.shared.offRouteThresholdMeters
        if distanceFromRoute > offRouteThreshold {
            // Send notification for off-route vehicle
            NotificationManager.shared.sendOffRouteAlert(
                tripId: trip.id,
                tripTitle: trip.title,
                distanceOffRoute: distanceFromRoute
            )
        }
    }
    
    func distanceFromRoute(location: CLLocationCoordinate2D, route: MKRoute) -> Double {
        // This is a simplified implementation - in a real app, you would use
        // more sophisticated algorithms to determine distance from a polyline
        
        let locationPoint = MKMapPoint(location)
        var minDistance = Double.greatestFiniteMagnitude
        
        // Get the polyline points from the route
        var routePoints: [MKMapPoint] = []
        let pointCount = route.polyline.pointCount
        
        let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: pointCount)
        route.polyline.getCoordinates(coordinates, range: NSRange(location: 0, length: pointCount))
        
        // Convert CLLocationCoordinate2D to MKMapPoint for distance calculations
        for i in 0..<pointCount {
            let coordinate = coordinates[i]
            let mapPoint = MKMapPoint(coordinate)
            routePoints.append(mapPoint)
        }
        
        coordinates.deallocate()
        
        // Calculate minimum distance to any segment of the route
        for i in 0..<routePoints.count - 1 {
            let segment = (routePoints[i], routePoints[i+1])
            let distance = distanceFromPointToLineSegment(point: locationPoint, lineStart: segment.0, lineEnd: segment.1)
            minDistance = min(minDistance, distance)
        }
        
        // Convert to meters
        return minDistance
    }
    
    func distanceFromPointToLineSegment(point: MKMapPoint, lineStart: MKMapPoint, lineEnd: MKMapPoint) -> Double {
        let lineLength = lineStart.distance(to: lineEnd)
        
        // Handle case where line segment is a point
        if lineLength == 0 {
            return point.distance(to: lineStart)
        }
        
        // Calculate projection of point onto line
        let t = ((point.x - lineStart.x) * (lineEnd.x - lineStart.x) + 
                 (point.y - lineStart.y) * (lineEnd.y - lineStart.y)) / (lineLength * lineLength)
        
        if t < 0 {
            // Point is beyond lineStart
            return point.distance(to: lineStart)
        } else if t > 1 {
            // Point is beyond lineEnd
            return point.distance(to: lineEnd)
        } else {
            // Point projects onto line segment
            let projection = MKMapPoint(
                x: lineStart.x + t * (lineEnd.x - lineStart.x),
                y: lineStart.y + t * (lineEnd.y - lineStart.y)
            )
            return point.distance(to: projection)
        }
    }
    
    // MARK: - Delay Monitoring
    
    func checkForTripDelays(trip: Trip) {
        // Only proceed if trip is in progress
        if trip.status != .inProgress {
            return
        }
        
        // We need the scheduled arrival time (end time)
        if trip.scheduledEndTime == nil {
            return
        }
        
        // Make sure we have a vehicleId
        if trip.vehicleId == nil {
            return
        }
        
        // Now that we know vehicleId exists, we can safely unwrap
        let vehicleId = trip.vehicleId!
        
        // Check if we have the vehicle location
        if vehicleLocations[vehicleId] == nil {
            return
        }
        
        // Check if we have a monitored route
        if monitoredRoutes[vehicleId] == nil {
            return
        }
        
        // Now we can safely use the unwrapped values
        let scheduledArrival = trip.scheduledEndTime
        let vehicleLocation = vehicleLocations[vehicleId]!.asLocation
        let route = monitoredRoutes[vehicleId]!
        
        // Calculate estimated time of arrival
        let remainingDistance = estimateRemainingDistance(vehicleLocation: vehicleLocation, route: route)
        let estimatedTimeToArrival = estimateTimeToArrival(remainingDistance: remainingDistance, vehicleId: vehicleId)
        
        // Calculate projected arrival time - this is a non-optional Date
        let projectedArrival = Date().addingTimeInterval(estimatedTimeToArrival)
        
        // Calculate the delay
        let delayInSeconds = projectedArrival.timeIntervalSince(scheduledArrival)
        
        // Check if there's a delay
        if delayInSeconds > 0 {
            let delayMinutes = Int(delayInSeconds / 60)
            let delayThreshold = NotificationManager.shared.delayThresholdMinutes
            
            // Send notification if delay exceeds threshold
            if delayMinutes >= delayThreshold {
                NotificationManager.shared.sendDelayAlert(
                    tripId: trip.id,
                    tripTitle: trip.title,
                    delayMinutes: delayMinutes
                )
            }
        }
    }
    
    private func estimateRemainingDistance(vehicleLocation: CLLocation, route: MKRoute) -> Double {
        // This is a simplified implementation
        // In a real app, you would calculate the remaining distance along the route
        // by finding the closest point on the route to the vehicle's current location
        // and then calculating the distance from that point to the end of the route
        
        // For simplicity, we'll estimate based on straight-line distance to destination
        let pointCount = route.polyline.pointCount
        
        let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: pointCount)
        route.polyline.getCoordinates(coordinates, range: NSRange(location: 0, length: pointCount))
        
        // Get the last coordinate
        let endCoordinate = coordinates[pointCount - 1]
        
        coordinates.deallocate()
        
        let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
        return vehicleLocation.distance(from: endLocation)
    }
    
    private func estimateTimeToArrival(remainingDistance: Double, vehicleId: String) -> TimeInterval {
        // In a real app, you would use more sophisticated methods including:
        // - Current vehicle speed from GPS
        // - Traffic conditions from an API
        // - Historical travel time data
        
        // For simplicity, we'll use an average speed assumption
        let averageSpeedMetersPerSecond = 13.9 // ~50 km/h or ~30 mph
        
        return remainingDistance / averageSpeedMetersPerSecond
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        self.location = location
        isLoadingLocation = false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        isLoadingLocation = false
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            break
        }
    }
}

enum LocationError: Error {
    case locationNotFound
    case notAuthorized
    
    var localizedDescription: String {
        switch self {
        case .locationNotFound:
            return "Could not determine your location"
        case .notAuthorized:
            return "Location access not authorized"
        }
    }
} 