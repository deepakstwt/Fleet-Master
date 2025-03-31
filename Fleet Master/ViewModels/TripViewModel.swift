import Foundation
import SwiftUI
import MapKit
import Combine

class TripViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var searchText: String = ""
    @Published var isShowingAddTrip = false
    @Published var isShowingEditTrip = false
    @Published var isShowingAssignDriver = false
    @Published var selectedTrip: Trip?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var filterStatus: TripStatus?
    
    // Form properties
    @Published var title = ""
    @Published var startLocation = ""
    @Published var endLocation = ""
    @Published var scheduledStartTime = Date()
    @Published var scheduledEndTime = Date().addingTimeInterval(3600) // 1 hour later
    @Published var status: TripStatus = TripStatus.scheduled
    @Published var driverId: String?
    @Published var vehicleId: String?
    @Published var description = ""
    @Published var distance: Double?
    @Published var notes = ""
    
    // Route and location properties
    private var locationManager = LocationManager()
    @Published var routeInformation: RouteInformation?
    @Published var isLoadingRoute = false
    @Published var routeError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTimer: Timer?
    
    init() {
        // Add location access request during initialization
        locationManager.requestWhenInUseAuthorization()
        
        // Setup listeners for address changes to calculate routes
        setupLocationCalculation()
        
        // Start the timer to check trip statuses
        startStatusCheckTimer()
    }
    
    deinit {
        stopStatusCheckTimer()
    }
    
    private func startStatusCheckTimer() {
        // Check every minute for trip status updates
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkAndUpdateTripStatuses()
        }
        // Run an initial check immediately
        checkAndUpdateTripStatuses()
    }
    
    private func stopStatusCheckTimer() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
    }
    
    private func checkAndUpdateTripStatuses() {
        let now = Date()
        
        for trip in trips {
            if trip.status == .scheduled {
                // If the scheduled start time has passed, update to in progress
                if trip.scheduledStartTime <= now {
                    if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                        trips[index].status = .inProgress
                        trips[index].actualStartTime = now
                    }
                }
            }
        }
    }
    
    private func setupLocationCalculation() {
        Publishers.CombineLatest($startLocation, $endLocation)
            .debounce(for: 1.0, scheduler: RunLoop.main)
            .filter { !$0.0.isEmpty && !$0.1.isEmpty }
            .sink { [weak self] start, end in
                self?.calculateRouteForForm(from: start, to: end)
            }
            .store(in: &cancellables)
    }
    
    func calculateRouteForForm(from start: String, to end: String) {
        guard !start.isEmpty && !end.isEmpty else { return }
        
        isLoadingRoute = true
        routeError = nil
        
        locationManager.calculateRoute(from: start, to: end) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingRoute = false
                
                switch result {
                case .success(let route):
                    self.routeInformation = RouteInformation(distance: route.distance, time: route.expectedTravelTime)
                    self.distance = route.distance / 1000 // Convert to km
                case .failure(let error):
                    self.routeError = error.localizedDescription
                    self.routeInformation = nil
                }
            }
        }
    }
    
    var filteredTrips: [Trip] {
        let filtered = trips.filter { trip in
            if let filterStatus = filterStatus, trip.status != filterStatus {
                return false
            }
            
            if searchText.isEmpty {
                return true
            } else {
                return trip.title.localizedCaseInsensitiveContains(searchText) ||
                    trip.id.localizedCaseInsensitiveContains(searchText) ||
                    trip.startLocation.localizedCaseInsensitiveContains(searchText) ||
                    trip.endLocation.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by scheduled start time, most recent first
        return filtered.sorted { $0.scheduledStartTime > $1.scheduledStartTime }
    }
    
    var upcomingTrips: [Trip] {
        let now = Date()
        return trips.filter { $0.scheduledStartTime > now && $0.status == TripStatus.scheduled }
            .sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }
    
    var inProgressTrips: [Trip] {
        return trips.filter { $0.status == TripStatus.inProgress }
            .sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }
    
    func addTrip() {
        guard !title.isEmpty, !startLocation.isEmpty, !endLocation.isEmpty, !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        // Generate a unique ID
        let newId = "T\(trips.count + 1)"
        
        // Add route information before creating the trip
        let tripRouteInfo = routeInformation
        
        // Add the new trip
        let newTrip = Trip(id: newId, 
                           title: title, 
                           startLocation: startLocation, 
                           endLocation: endLocation, 
                           scheduledStartTime: scheduledStartTime, 
                           scheduledEndTime: scheduledEndTime, 
                           status: status, 
                           driverId: driverId, 
                           vehicleId: vehicleId, 
                           description: description,
                           distance: distance,
                           notes: notes.isEmpty ? nil : notes,
                           routeInfo: tripRouteInfo)
        
        trips.append(newTrip)
        resetForm()
        isShowingAddTrip = false
    }
    
    func updateTrip() {
        guard let selectedTrip = selectedTrip else { return }
        guard !title.isEmpty, !startLocation.isEmpty, !endLocation.isEmpty, !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        if let index = trips.firstIndex(where: { $0.id == selectedTrip.id }) {
            trips[index] = Trip(id: selectedTrip.id, 
                               title: title, 
                               startLocation: startLocation, 
                               endLocation: endLocation, 
                               scheduledStartTime: scheduledStartTime, 
                               scheduledEndTime: scheduledEndTime, 
                               status: status, 
                               driverId: driverId, 
                               vehicleId: vehicleId, 
                               description: description,
                               distance: distance,
                               actualStartTime: selectedTrip.actualStartTime, 
                               actualEndTime: selectedTrip.actualEndTime, 
                               notes: notes.isEmpty ? nil : notes,
                               routeInfo: routeInformation ?? selectedTrip.routeInfo)
        }
        
        isShowingEditTrip = false
        resetForm()
    }
    
    func assignDriver(to trip: Trip, driverId: String?, vehicleId: String?) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        
        trips[index].driverId = driverId
        trips[index].vehicleId = vehicleId
        
        alertMessage = "Driver assigned to trip successfully!"
        showAlert = true
    }
    
    func updateTripStatus(trip: Trip, newStatus: TripStatus) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        
        let now = Date()
        
        switch newStatus {
        case .inProgress:
            trips[index].actualStartTime = now
        case .completed:
            trips[index].actualEndTime = now
        default:
            break
        }
        
        trips[index].status = newStatus
    }
    
    func cancelTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index].status = .cancelled
    }
    
    func selectTripForEdit(trip: Trip) {
        selectedTrip = trip
        title = trip.title
        startLocation = trip.startLocation
        endLocation = trip.endLocation
        scheduledStartTime = trip.scheduledStartTime
        scheduledEndTime = trip.scheduledEndTime
        status = trip.status
        driverId = trip.driverId
        vehicleId = trip.vehicleId
        description = trip.description
        distance = trip.distance
        notes = trip.notes ?? ""
        isShowingEditTrip = true
    }
    
    func resetForm() {
        title = ""
        startLocation = ""
        endLocation = ""
        scheduledStartTime = Date()
        scheduledEndTime = Date().addingTimeInterval(3600)
        status = TripStatus.scheduled
        driverId = nil
        vehicleId = nil
        description = ""
        distance = nil
        notes = ""
        isShowingAddTrip = false
    }
    
    func getTripById(_ id: String) -> Trip? {
        return trips.first { $0.id == id }
    }
    
    func getTripsForDriver(_ driverId: String) -> [Trip] {
        return trips.filter { $0.driverId == driverId }
    }
    
    func getTripsForVehicle(_ vehicleId: String) -> [Trip] {
        return trips.filter { $0.vehicleId == vehicleId }
    }
    
    // Adds route information to a trip
    func addRouteInfoToTrip() {
        if let routeInfo = routeInformation {
            self.distance = routeInfo.distance / 1000 // Convert to km
        }
    }
    
    // Updates route info for an existing trip
    func updateTripRouteInfo(trip: Trip, routeInfo: RouteInformation) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        
        // Update the trip with the new route info
        trips[index].routeInfo = routeInfo
        // Also update distance for consistency
        trips[index].distance = routeInfo.distance / 1000
    }
} 
