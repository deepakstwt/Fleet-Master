import Foundation
import SwiftUI

class VehicleViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var searchText: String = ""
    @Published var isShowingAddVehicle = false
    @Published var isShowingEditVehicle = false
    @Published var selectedVehicle: Vehicle?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var filterActive = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Form properties
    @Published var registrationNumber = ""
    @Published var make = ""
    @Published var model = ""
    @Published var year = Calendar.current.component(.year, from: Date())
    @Published var vin = ""
    @Published var color = ""
    @Published var selectedFuelType = FuelType.petrol
    @Published var selectedVehicleType = VehicleType.lmvTr
    @Published var rcExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var insuranceNumber = ""
    @Published var insuranceExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var pollutionCertificateNumber = ""
    @Published var pollutionCertificateExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var lastServiceDate: Date? = Date()
    @Published var nextServiceDue: Date? = Date().addingTimeInterval(90*24*60*60) // 3 months from now
    @Published var currentOdometer = 0
    @Published var additionalNotes = ""
    
    private let vehicleManager = VehicleSupabaseManager.shared
    
    var filteredVehicles: [Vehicle] {
        let filtered = vehicles.filter { vehicle in
            if filterActive && !vehicle.isActive {
                return false
            }
            
            if searchText.isEmpty {
                return true
            } else {
                return vehicle.registrationNumber.localizedCaseInsensitiveContains(searchText) ||
                    vehicle.make.localizedCaseInsensitiveContains(searchText) ||
                    vehicle.model.localizedCaseInsensitiveContains(searchText) ||
                    vehicle.vin.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var activeVehicles: [Vehicle] {
        return vehicles.filter { $0.isActive }
    }
    
    init() {
        Task {
            await fetchVehicles()
        }
    }
    
    // MARK: - Database Operations
    
    @MainActor
    func fetchVehicles() async {
        isLoading = true
        errorMessage = nil
        
        print("===== Starting vehicle fetch operation =====")
        
        do {
            // Load all vehicles from Supabase
            print("Calling vehicleManager.fetchAllVehicles()...")
            vehicles = try await vehicleManager.fetchAllVehicles()
            print("Successfully loaded \(vehicles.count) vehicles")
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
            vehicles = []
            print("❌ Error fetching vehicles: \(error)")
        }
        
        print("===== Completed vehicle fetch operation =====")
    }
    
    @MainActor
    func searchVehiclesInDatabase() async {
        guard !searchText.isEmpty else {
            await fetchVehicles()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            vehicles = try await vehicleManager.searchVehicles(searchText: searchText)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to search vehicles: \(error.localizedDescription)"
            print("Error searching vehicles: \(error)")
        }
    }
    
    func addVehicle() {
        let newVehicle = Vehicle(
            registrationNumber: registrationNumber,
            make: make,
            model: model,
            year: year,
            vin: vin,
            color: color,
            fuelType: selectedFuelType,
            vehicleType: selectedVehicleType,
            rcExpiryDate: rcExpiryDate,
            insuranceNumber: insuranceNumber,
            insuranceExpiryDate: insuranceExpiryDate,
            pollutionCertificateNumber: pollutionCertificateNumber,
            pollutionCertificateExpiryDate: pollutionCertificateExpiryDate,
            lastServiceDate: lastServiceDate,
            nextServiceDue: nextServiceDue,
            currentOdometer: currentOdometer,
            additionalNotes: additionalNotes.isEmpty ? nil : additionalNotes
        )
        
        Task {
            await addVehicleToDatabase(newVehicle)
        }
    }
    
    @MainActor
    private func addVehicleToDatabase(_ vehicle: Vehicle) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let savedVehicle = try await vehicleManager.addVehicle(vehicle)
            vehicles.append(savedVehicle)
            resetForm()
            isLoading = false
            alertMessage = "Vehicle added successfully!"
            showAlert = true
        } catch {
            isLoading = false
            errorMessage = "Failed to add vehicle: \(error.localizedDescription)"
            print("Error adding vehicle: \(error)")
        }
    }
    
    func updateVehicle() {
        guard let selectedVehicle = selectedVehicle else { return }
        
        // Create updated vehicle object
        var updatedVehicle = selectedVehicle
        updatedVehicle.color = color
        updatedVehicle.fuelType = selectedFuelType
        updatedVehicle.rcExpiryDate = rcExpiryDate
        updatedVehicle.insuranceNumber = insuranceNumber
        updatedVehicle.insuranceExpiryDate = insuranceExpiryDate
        updatedVehicle.pollutionCertificateNumber = pollutionCertificateNumber
        updatedVehicle.pollutionCertificateExpiryDate = pollutionCertificateExpiryDate
        updatedVehicle.lastServiceDate = lastServiceDate
        updatedVehicle.nextServiceDue = nextServiceDue
        updatedVehicle.currentOdometer = currentOdometer
        updatedVehicle.additionalNotes = additionalNotes.isEmpty ? nil : additionalNotes
        
        Task {
            await updateVehicleInDatabase(updatedVehicle)
        }
    }
    
    @MainActor
    private func updateVehicleInDatabase(_ vehicle: Vehicle) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedVehicle = try await vehicleManager.updateVehicle(vehicle)
            
            // Update local array
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            }
            
            resetForm()
            isShowingEditVehicle = false
            self.selectedVehicle = nil
            isLoading = false
            
            alertMessage = "Vehicle updated successfully!"
            showAlert = true
        } catch {
            isLoading = false
            errorMessage = "Failed to update vehicle: \(error.localizedDescription)"
            print("Error updating vehicle: \(error)")
            
            // For development fallback only - remove in production
            if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                vehicles[index] = vehicle
            }
            
            resetForm()
            isShowingEditVehicle = false
            self.selectedVehicle = nil
            
            alertMessage = "Vehicle updated in local state only (offline mode)"
            showAlert = true
        }
    }
    
    func toggleVehicleStatus(vehicle: Vehicle) {
        Task {
            await toggleVehicleStatusInDatabase(vehicle)
        }
    }
    
    @MainActor
    private func toggleVehicleStatusInDatabase(_ vehicle: Vehicle) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedVehicle = try await vehicleManager.toggleVehicleStatus(
                vehicleId: vehicle.id, 
                isActive: !vehicle.isActive
            )
            
            // Update local array
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to toggle vehicle status: \(error.localizedDescription)"
            print("Error toggling vehicle status: \(error)")
            
            // For development fallback only - remove in production
            if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                vehicles[index].isActive.toggle()
            }
        }
    }
    
    func selectVehicleForEdit(vehicle: Vehicle) {
        selectedVehicle = vehicle
        registrationNumber = vehicle.registrationNumber
        make = vehicle.make
        model = vehicle.model
        year = vehicle.year
        vin = vehicle.vin
        color = vehicle.color
        selectedFuelType = vehicle.fuelType
        selectedVehicleType = vehicle.vehicleType
        rcExpiryDate = vehicle.rcExpiryDate
        insuranceNumber = vehicle.insuranceNumber
        insuranceExpiryDate = vehicle.insuranceExpiryDate
        pollutionCertificateNumber = vehicle.pollutionCertificateNumber
        pollutionCertificateExpiryDate = vehicle.pollutionCertificateExpiryDate
        lastServiceDate = vehicle.lastServiceDate
        nextServiceDue = vehicle.nextServiceDue
        currentOdometer = vehicle.currentOdometer
        additionalNotes = vehicle.additionalNotes ?? ""
        isShowingEditVehicle = true
    }
    
    func resetForm() {
        registrationNumber = ""
        make = ""
        model = ""
        year = Calendar.current.component(.year, from: Date())
        vin = ""
        color = ""
        selectedFuelType = .petrol
        selectedVehicleType = .lmvTr
        rcExpiryDate = Date().addingTimeInterval(365*24*60*60)
        insuranceNumber = ""
        insuranceExpiryDate = Date().addingTimeInterval(365*24*60*60)
        pollutionCertificateNumber = ""
        pollutionCertificateExpiryDate = Date().addingTimeInterval(365*24*60*60)
        lastServiceDate = Date()
        nextServiceDue = Date().addingTimeInterval(90*24*60*60)
        currentOdometer = 0
        additionalNotes = ""
    }
    
    func getVehicleById(_ id: String) -> Vehicle? {
        return vehicles.first { $0.id == id }
    }
    
    func areDocumentsValid(for vehicle: Vehicle) -> Bool {
        let now = Date()
        return vehicle.rcExpiryDate > now &&
               vehicle.insuranceExpiryDate > now &&
               vehicle.pollutionCertificateExpiryDate > now
    }
    
    func isServiceDue(for vehicle: Vehicle) -> Bool {
        guard let nextDue = vehicle.nextServiceDue else { return false }
        let now = Date()
        return nextDue < now
    }
} 