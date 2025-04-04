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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Form properties
    @Published var title = ""
    @Published var startLocation = ""
    @Published var endLocation = ""
    @Published var scheduledStartTime = Date()
    @Published var scheduledEndTime = Date()
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
    
    // Supabase manager for CRUD operations
    private let tripSupabaseManager = TripSupabaseManager.shared
    
    init() {
        // Add location access request during initialization
        locationManager.requestWhenInUseAuthorization()
        
        // Setup listeners for address changes to calculate routes
        setupLocationCalculation()
        
        // Load trips from Supabase
        Task {
            await loadTrips()
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
    
    // MARK: - Computed Properties
    
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
        return trips.filter { $0.status == TripStatus.ongoing }
            .sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }
    
    // MARK: - Supabase CRUD Operations
    
    /// Load all trips from Supabase
    @MainActor
    func loadTrips() async {
        isLoading = true
        errorMessage = nil
        
        do {
            trips = try await tripSupabaseManager.fetchAllTrips()
        } catch {
            errorMessage = "Failed to load trips: \(error.localizedDescription)"
            print("Error loading trips: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load trips with status filter from Supabase
    @MainActor
    func loadTrips(withStatus status: TripStatus? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            trips = try await tripSupabaseManager.fetchTrips(status: status)
        } catch {
            errorMessage = "Failed to load trips: \(error.localizedDescription)"
            print("Error loading trips: \(error)")
        }
        
        isLoading = false
    }
    
    /// Search trips from Supabase
    @MainActor
    func searchTripsFromSupabase() async {
        guard !searchText.isEmpty else {
            await loadTrips(withStatus: filterStatus)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            trips = try await tripSupabaseManager.searchTrips(searchText: searchText)
            
            // Apply filter if needed
            if let status = filterStatus {
                trips = trips.filter { $0.status == status }
            }
        } catch {
            errorMessage = "Failed to search trips: \(error.localizedDescription)"
            print("Error searching trips: \(error)")
        }
        
        isLoading = false
    }
    
    /// Add a new trip to Supabase
    @MainActor
    func addTrip() {
        guard !title.isEmpty, !startLocation.isEmpty, !endLocation.isEmpty, !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        // Add the new trip
        let newTrip = Trip(
            id: UUID().uuidString, // Supabase will handle this, but we need a value
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
            routeInfo: routeInformation
        )
        
        Task {
            isLoading = true
            
            do {
                let addedTrip = try await tripSupabaseManager.addTrip(newTrip)
                await MainActor.run {
                    trips.append(addedTrip)
                    resetForm()
                    isShowingAddTrip = false
                    alertMessage = "Trip added successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add trip: \(error.localizedDescription)"
                    print("Error adding trip: \(error)")
                    showAlert = true
                    alertMessage = "Failed to add trip: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Update an existing trip in Supabase
    @MainActor
    func updateTrip() {
        guard let selectedTrip = selectedTrip else { return }
        guard !title.isEmpty, !startLocation.isEmpty, !endLocation.isEmpty, !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        let updatedTrip = Trip(
            id: selectedTrip.id, 
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
            routeInfo: routeInformation ?? selectedTrip.routeInfo
        )
        
        Task {
            isLoading = true
            
            do {
                let updated = try await tripSupabaseManager.updateTrip(updatedTrip)
                await MainActor.run {
                    if let index = trips.firstIndex(where: { $0.id == updated.id }) {
                        trips[index] = updated
                    }
                    resetForm()
                    isShowingEditTrip = false
                    alertMessage = "Trip updated successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update trip: \(error.localizedDescription)"
                    print("Error updating trip: \(error)")
                    showAlert = true
                    alertMessage = "Failed to update trip: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Assign a driver and vehicle to a trip in Supabase
    func assignDriver(to trip: Trip, driverId: String?, vehicleId: String?) {
        guard let driverId = driverId, let vehicleId = vehicleId else {
            alertMessage = "Please select both a driver and a vehicle"
            showAlert = true
            return
        }
        
        Task {
            isLoading = true
            
            do {
                let updatedTrip = try await tripSupabaseManager.assignDriverAndVehicle(tripId: trip.id, driverId: driverId, vehicleId: vehicleId)
                
                await MainActor.run {
                    if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                        trips[index] = updatedTrip
                    }
                    
                    alertMessage = "Driver assigned to trip successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to assign driver: \(error.localizedDescription)"
                    print("Error assigning driver: \(error)")
                    alertMessage = "Failed to assign driver: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Update trip status in Supabase
    func updateTripStatus(trip: Trip, newStatus: TripStatus) {
        var actualStart: Date? = nil
        var actualEnd: Date? = nil
        let now = Date()
        
        // Set actual start/end times based on status
        switch newStatus {
        case .ongoing:
            actualStart = now
        case .completed:
            actualEnd = now
        default:
            break
        }
        
        Task {
            isLoading = true
            
            do {
                let updatedTrip = try await tripSupabaseManager.updateTripStatus(
                    tripId: trip.id,
                    status: newStatus,
                    actualStartTime: actualStart,
                    actualEndTime: actualEnd
                )
                
                await MainActor.run {
                    if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                        trips[index] = updatedTrip
                    }
                    
                    alertMessage = "Trip status updated successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update trip status: \(error.localizedDescription)"
                    print("Error updating trip status: \(error)")
                    alertMessage = "Failed to update trip status: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Cancel a trip in Supabase
    func cancelTrip(_ trip: Trip) {
        updateTripStatus(trip: trip, newStatus: .cancelled)
    }
    
    /// Async version of updateTripStatus that throws errors
    func updateTripStatusAsync(trip: Trip, newStatus: TripStatus) async throws {
        var actualStart: Date? = nil
        var actualEnd: Date? = nil
        let now = Date()
        
        // Set actual start/end times based on status
        switch newStatus {
        case .ongoing:
            actualStart = now
        case .completed:
            actualEnd = now
        default:
            break
        }
        
        // Direct call to the Supabase manager, no wrapping in Task since caller manages that
        let updatedTrip = try await tripSupabaseManager.updateTripStatus(
            tripId: trip.id,
            status: newStatus,
            actualStartTime: actualStart,
            actualEndTime: actualEnd
        )
                
        // Update local state on success
        await MainActor.run {
            if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                trips[index] = updatedTrip
            }
        }
        
        return
    }
    
    /// Async version of cancelTrip that throws errors
    func cancelTripAsync(_ trip: Trip) async throws {
        try await updateTripStatusAsync(trip: trip, newStatus: .cancelled)
    }
    
    /// Delete a trip from Supabase
    func deleteTrip(_ trip: Trip) {
        Task {
            isLoading = true
            
            do {
                try await tripSupabaseManager.deleteTrip(id: trip.id)
                
                await MainActor.run {
                    trips.removeAll { $0.id == trip.id }
                    alertMessage = "Trip deleted successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete trip: \(error.localizedDescription)"
                    print("Error deleting trip: \(error)")
                    alertMessage = "Failed to delete trip: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        routeInformation = trip.routeInfo
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
        routeInformation = nil
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
        // Create updated trip with new route info
        var updatedTrip = trip
        updatedTrip.routeInfo = routeInfo
        updatedTrip.distance = routeInfo.distance / 1000 // Convert to km
        
        // Update locally first for UI responsiveness
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index].routeInfo = routeInfo
            trips[index].distance = routeInfo.distance / 1000
        }
        
        // Then update in Supabase
        Task {
            do {
                _ = try await tripSupabaseManager.updateTrip(updatedTrip)
                print("Trip route info updated successfully in database")
            } catch {
                print("Error updating trip route info: \(error)")
            }
        }
    }
    
    // Refreshes all trips from Supabase
    func refreshTrips() {
        Task {
            await loadTrips()
        }
    }
} 
