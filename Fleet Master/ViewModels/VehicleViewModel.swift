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
    
    func addVehicle(status: VehicleStatus = .available) {
        // First validate all inputs
        if !isVehicleFormValid() {
            errorMessage = "Please correct the validation errors before adding the vehicle."
            return
        }
        
        let newVehicle = Vehicle(
            registrationNumber: registrationNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            vin: vin.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            color: color.trimmingCharacters(in: .whitespacesAndNewlines),
            fuelType: selectedFuelType,
            vehicleType: selectedVehicleType,
            isActive: true,
            vehicle_status: status,
            rcExpiryDate: rcExpiryDate,
            insuranceNumber: insuranceNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            insuranceExpiryDate: insuranceExpiryDate,
            pollutionCertificateNumber: pollutionCertificateNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            pollutionCertificateExpiryDate: pollutionCertificateExpiryDate,
            lastServiceDate: lastServiceDate,
            nextServiceDue: nextServiceDue,
            currentOdometer: currentOdometer,
            additionalNotes: additionalNotes.isEmpty ? nil : additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    func updateVehicle(status: VehicleStatus? = nil) {
        guard let selectedVehicle = selectedVehicle else { return }
        
        // Create updated vehicle object
        var updatedVehicle = selectedVehicle
        updatedVehicle.color = color.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedVehicle.fuelType = selectedFuelType
        updatedVehicle.rcExpiryDate = rcExpiryDate
        updatedVehicle.insuranceNumber = insuranceNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        updatedVehicle.insuranceExpiryDate = insuranceExpiryDate
        updatedVehicle.pollutionCertificateNumber = pollutionCertificateNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        updatedVehicle.pollutionCertificateExpiryDate = pollutionCertificateExpiryDate
        updatedVehicle.lastServiceDate = lastServiceDate
        updatedVehicle.nextServiceDue = nextServiceDue
        updatedVehicle.currentOdometer = currentOdometer
        updatedVehicle.additionalNotes = additionalNotes.isEmpty ? nil : additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update the vehicle status if provided
        if let status = status {
            updatedVehicle.vehicle_status = status
        }
        
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
    
    func updateVehicleStatus(vehicle: Vehicle, status: VehicleStatus) {
        Task {
            await updateVehicleStatusInDatabase(vehicle, status: status)
        }
    }
    
    private func updateVehicleStatusInDatabase(_ vehicle: Vehicle, status: VehicleStatus) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var updatedVehicle = vehicle
            updatedVehicle.vehicle_status = status
            
            let savedVehicle = try await vehicleManager.updateVehicle(updatedVehicle)
            
            // Update local array
            if let index = vehicles.firstIndex(where: { $0.id == savedVehicle.id }) {
                vehicles[index] = savedVehicle
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to update vehicle status: \(error.localizedDescription)"
            print("Error updating vehicle status: \(error)")
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
    
    // MARK: - Vehicle Validation Methods
    
    /// Validates if the registration number follows the Indian vehicle registration format
    /// Format: [State Code][District Number][Series][Vehicle Number] - e.g., MH12AB1234
    func isValidRegistrationNumber(_ registration: String? = nil) -> Bool {
        let registrationToValidate = registration ?? self.registrationNumber
        
        // Trim and uppercase the input
        let cleanRegistration = registrationToValidate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Basic validation - Minimum 8 characters, maximum 11 characters
        guard cleanRegistration.count >= 8 && cleanRegistration.count <= 11 else {
            return false
        }
        
        // Check for the standard Indian registration format (e.g., MH12AB1234)
        // State code: 2 letters, District code: 1-2 digits, Series: 1-2 letters, Number: 1-4 digits
        let regex = "^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{1,4}$"
        return cleanRegistration.range(of: regex, options: .regularExpression) != nil
    }
    
    /// Returns a detailed error message for an invalid registration number
    func registrationNumberErrorMessage() -> String? {
        let registration = self.registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if registration.isEmpty {
            return "Registration number is required"
        }
        
        if !isValidRegistrationNumber() {
            return "Invalid format. Expected: XXNNXX1234 (State code, district, series, number)"
        }
        
        return nil
    }
    
    /// Validates if the VIN follows the standard 17-character VIN format
    func isValidVIN(_ vin: String? = nil) -> Bool {
        let vinToValidate = vin ?? self.vin
        
        // Trim and uppercase the input
        let cleanVIN = vinToValidate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Standard VIN is 17 characters
        guard cleanVIN.count == 17 else {
            return false
        }
        
        // VIN should only contain letters and numbers (excluding I, O, Q)
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
        let vinCharacterSet = CharacterSet(charactersIn: cleanVIN)
        return validCharacters.isSuperset(of: vinCharacterSet)
    }
    
    /// Returns a detailed error message for an invalid VIN
    func vinErrorMessage() -> String? {
        let vin = self.vin.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if vin.isEmpty {
            return "VIN is required"
        }
        
        if vin.count != 17 {
            return "VIN must be exactly 17 characters"
        }
        
        if !isValidVIN() {
            return "VIN contains invalid characters (Only A-Z, 0-9, excluding I, O, Q)"
        }
        
        return nil
    }
    
    /// Validates if the insurance number is in a valid format
    func isValidInsuranceNumber(_ insurance: String? = nil) -> Bool {
        let insuranceToValidate = insurance ?? self.insuranceNumber
        
        // Trim whitespace
        let cleanInsurance = insuranceToValidate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation - at least 8 characters, alphanumeric with possible hyphens
        guard cleanInsurance.count >= 8 else {
            return false
        }
        
        // Insurance numbers typically are alphanumeric with possible hyphens or slashes
        let regex = "^[A-Za-z0-9\\-\\/]{8,}$"
        return cleanInsurance.range(of: regex, options: .regularExpression) != nil
    }
    
    /// Returns a detailed error message for an invalid insurance number
    func insuranceNumberErrorMessage() -> String? {
        let insurance = self.insuranceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if insurance.isEmpty {
            return "Insurance number is required"
        }
        
        if !isValidInsuranceNumber() {
            return "Insurance number must be at least 8 alphanumeric characters"
        }
        
        return nil
    }
    
    /// Validates if the pollution certificate number is in a valid format
    func isValidPollutionCertificateNumber(_ certificate: String? = nil) -> Bool {
        let certificateToValidate = certificate ?? self.pollutionCertificateNumber
        
        // Trim whitespace
        let cleanCertificate = certificateToValidate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation - at least 6 characters, alphanumeric with possible hyphens
        guard cleanCertificate.count >= 6 else {
            return false
        }
        
        // Pollution certificates typically are alphanumeric with possible hyphens
        let regex = "^[A-Za-z0-9\\-]{6,}$"
        return cleanCertificate.range(of: regex, options: .regularExpression) != nil
    }
    
    /// Returns a detailed error message for an invalid pollution certificate number
    func pollutionCertificateNumberErrorMessage() -> String? {
        let certificate = self.pollutionCertificateNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if certificate.isEmpty {
            return "Pollution certificate number is required"
        }
        
        if !isValidPollutionCertificateNumber() {
            return "Pollution certificate must be at least 6 alphanumeric characters"
        }
        
        return nil
    }
    
    /// Validates if the year is valid based on acceptable range
    func isValidYear(_ year: Int? = nil) -> Bool {
        let yearToValidate = year ?? self.year
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Year should be between 1990 and the current year + 1 (for upcoming models)
        return yearToValidate >= 1990 && yearToValidate <= currentYear + 1
    }
    
    /// Returns a detailed error message for an invalid year
    func yearErrorMessage() -> String? {
        if !isValidYear() {
            let currentYear = Calendar.current.component(.year, from: Date())
            return "Year must be between 1990 and \(currentYear + 1)"
        }
        
        return nil
    }
    
    /// Comprehensive validation for the vehicle form
    func isVehicleFormValid() -> Bool {
        return isValidRegistrationNumber() &&
               !make.isEmpty &&
               !model.isEmpty &&
               isValidYear() &&
               isValidVIN() &&
               !color.isEmpty &&
               isValidInsuranceNumber() &&
               isValidPollutionCertificateNumber()
    }
    
    // MARK: - Vehicle Validation Help Text
    
    /// Help text explaining the Indian vehicle registration format
    static let registrationNumberHelpText = """
    Indian vehicle registration follows this format:
    
    XX NN XX NNNN where:
    - First 2 letters (XX): State code (e.g., MH for Maharashtra, KA for Karnataka)
    - 1-2 digits (NN): District code (e.g., 01, 12)
    - 1-3 letters (XX): Series (e.g., AB, C, XYZ)
    - 1-4 digits (NNNN): Vehicle number (e.g., 1234)
    
    Examples: MH01AB1234, KA02MG365, DL3CAB7749
    
    For special series like BH (Bharat Series), the format is slightly different.
    """
    
    /// Help text explaining the VIN format
    static let vinHelpText = """
    Vehicle Identification Number (VIN) must:
    - Be exactly 17 characters
    - Contain only letters and numbers (excluding I, O, Q)
    - Follow the global standard format
    
    Example: 1HGCM82633A004352
    """
} 
