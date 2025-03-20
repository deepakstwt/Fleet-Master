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
    @Published var routeInformation: (distance: CLLocationDistance, time: TimeInterval)?
    @Published var isLoadingRoute = false
    @Published var routeError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // For demo purposes, add some sample trips
        addSampleTrips()
        
        // Add location access request during initialization
        locationManager.requestLocationPermission()
        
        // Setup listeners for address changes to calculate routes
        setupLocationCalculation()
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
                    self.routeInformation = (route.distance, route.expectedTravelTime)
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
    
    func addSampleTrips() {
        let now = Date()
        
        trips = [
            Trip(
                title: "Client Meeting Pickup",
                startLocation: "Office HQ",
                endLocation: "Airport Terminal 3",
                scheduledStartTime: now.addingTimeInterval(3600), // 1 hour from now
                scheduledEndTime: now.addingTimeInterval(5400), // 1.5 hours from now
                description: "Pick up clients from office and take them to airport"
            ),
            Trip(
                title: "Delivery to Distribution Center",
                startLocation: "Warehouse A",
                endLocation: "Distribution Center B",
                scheduledStartTime: now.addingTimeInterval(-1800), // 30 mins ago
                scheduledEndTime: now.addingTimeInterval(1800), // 30 mins from now
                status: TripStatus.inProgress,
                driverId: "D2",
                vehicleId: "V3",
                description: "Deliver weekly inventory to distribution center",
                actualStartTime: now.addingTimeInterval(-1800)
            ),
            Trip(
                title: "Equipment Maintenance",
                startLocation: "Depot",
                endLocation: "Service Center",
                scheduledStartTime: now.addingTimeInterval(-86400), // 1 day ago
                scheduledEndTime: now.addingTimeInterval(-79200), // 20 hours ago
                status: TripStatus.completed,
                driverId: "D3",
                vehicleId: "V2",
                description: "Take equipment for scheduled maintenance",
                actualStartTime: now.addingTimeInterval(-86400),
                actualEndTime: now.addingTimeInterval(-79200)
            )
        ]
    }
    
    func addTrip() {
        guard !title.isEmpty, !startLocation.isEmpty, !endLocation.isEmpty, !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        // Generate a unique ID
        let newId = "T\(trips.count + 1)"
        
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
                           notes: notes.isEmpty ? nil : notes)
        
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
                                actualStartTime: selectedTrip.actualStartTime, actualEndTime: selectedTrip.actualEndTime, notes: notes.isEmpty ? nil : notes)
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
    
    func loadSampleData() {
        trips = [
            Trip(id: "T1", title: "Delivery to Downtown", startLocation: "Warehouse A", endLocation: "123 Main St", scheduledStartTime: Date().addingTimeInterval(3600), scheduledEndTime: Date().addingTimeInterval(7200), status: TripStatus.scheduled, driverId: "D1", vehicleId: "V1", description: "Deliver office supplies to the downtown branch", distance: 15.5),
            Trip(id: "T2", title: "Client Pickup", startLocation: "Office HQ", endLocation: "Airport Terminal 2", scheduledStartTime: Date().addingTimeInterval(-3600), scheduledEndTime: Date().addingTimeInterval(1800), status: TripStatus.inProgress, driverId: "D2", vehicleId: "V2", description: "Pick up client from the airport and bring to office for meeting", distance: 30.2, actualStartTime: Date().addingTimeInterval(-1800)),
            Trip(id: "T3", title: "Equipment Transport", startLocation: "Warehouse B", endLocation: "Construction Site C", scheduledStartTime: Date().addingTimeInterval(-86400), scheduledEndTime: Date().addingTimeInterval(-79200), status: TripStatus.completed, driverId: "D3", vehicleId: "V3", description: "Transport heavy equipment to the construction site", distance: 45.8, actualStartTime: Date().addingTimeInterval(-85000), actualEndTime: Date().addingTimeInterval(-78000)),
            Trip(id: "T4", title: "Executive Shuttle", startLocation: "CEO Residence", endLocation: "Board Meeting", scheduledStartTime: Date().addingTimeInterval(-7200), scheduledEndTime: Date().addingTimeInterval(-5400), status: TripStatus.cancelled, driverId: "D1", vehicleId: "V2", description: "Transport CEO to quarterly board meeting", distance: 22.1, notes: "Cancelled due to meeting being rescheduled"),
            Trip(id: "T5", title: "Supply Delivery", startLocation: "Supplier XYZ", endLocation: "Warehouse A", scheduledStartTime: Date().addingTimeInterval(86400), scheduledEndTime: Date().addingTimeInterval(93600), status: TripStatus.scheduled, driverId: nil, vehicleId: nil, description: "Pick up monthly supply order from vendor", distance: 60.0),
            Trip(id: "T6", title: "Maintenance Run", startLocation: "Garage", endLocation: "Service Center", scheduledStartTime: Date().addingTimeInterval(172800), scheduledEndTime: Date().addingTimeInterval(176400), status: TripStatus.scheduled, driverId: nil, vehicleId: "V4", description: "Take vehicle for scheduled maintenance", distance: 8.5)
        ]
    }
} 
