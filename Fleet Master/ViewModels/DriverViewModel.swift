import Foundation
import SwiftUI
import MessageUI

class DriverViewModel: ObservableObject,@unchecked Sendable{
    @Published var drivers: [Driver] = []
    @Published var searchText: String = "" {
        didSet {
            if !searchText.isEmpty && searchText.count > 2 {
                searchDebounceTimer?.invalidate()
                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    self?.searchDrivers()
                }
            } else if searchText.isEmpty && oldValue.count > 0 {
                // If search was cleared, reload all drivers
                fetchDrivers()
            }
        }
    }
    @Published var isShowingAddDriver = false
    @Published var isShowingEditDriver = false
    @Published var selectedDriver: Driver?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var filterActive = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Form properties
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var licenseNumber = ""
    @Published var isAvailable = true
    @Published var vehicleCategories: [String] = []
    
    // Instance of DriverSupabaseManager
    private let driverManager = DriverSupabaseManager.shared
    
    private var searchDebounceTimer: Timer?
    
    var filteredDrivers: [Driver] {
        let filtered = drivers.filter { driver in
            if filterActive && !driver.isActive {
                return false
            }
            
            if searchText.isEmpty {
                return true
            } else {
                return driver.name.localizedCaseInsensitiveContains(searchText) ||
                driver.id.localizedCaseInsensitiveContains(searchText) ||
                driver.email.localizedCaseInsensitiveContains(searchText) ||
                driver.licenseNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var availableDrivers: [Driver] {
        return drivers.filter { $0.isActive && $0.isAvailable }
    }
    
    init() {
        // Load drivers from Supabase
        fetchDrivers()
    }
    
    // MARK: - Data Operations
    
    /// Fetch all drivers from Supabase
    func fetchDrivers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedDrivers = try await driverManager.fetchAllDrivers()
                
                DispatchQueue.main.async {
                    self.drivers = fetchedDrivers
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load drivers: \(error.localizedDescription)"
                    self.isLoading = false
                    
                }
            }
        }
    }
    
    /// Add a new driver to Supabase
    func addDriver() {
        // Validate form inputs first
        if !isDriverFormValid() {
            return
        }
        
        isLoading = true
        
        // Clean up input values
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLicenseNumber = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        let newDriver = Driver(
            name: cleanName, 
            email: cleanEmail, 
            phone: cleanPhone, 
            licenseNumber: cleanLicenseNumber,
            isAvailable: isAvailable,
            vehicleCategories: vehicleCategories
        )
        
        Task {
            do {
                let createdDriver = try await driverManager.addDriver(newDriver)
                
                // Send the temporary password to the driver's email
                EmailService.shared.sendPasswordEmail(
                    to: createdDriver.email,
                    name: createdDriver.name,
                    password: newDriver.password // Use the password from our newDriver object since it's not returned from the server
                )
                
                DispatchQueue.main.async {
                    self.drivers.append(createdDriver)
                    self.resetForm()
                    self.isLoading = false
                    
                    // Updated success message without showing the UUID
                    self.alertMessage = "Driver added successfully! A welcome email with login details has been sent to \(createdDriver.email)."
                    self.showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to add driver: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error adding driver: \(error)")
                }
            }
        }
    }
    
    /// Update an existing driver in Supabase
    func updateDriver() {
        guard let selectedDriver = selectedDriver else { return }
        
        // Validate form inputs first
        if !isDriverFormValid() {
            return
        }
        
        isLoading = true
        
        // Clean up input values
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLicenseNumber = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        var updatedDriver = selectedDriver
        updatedDriver.name = cleanName
        updatedDriver.email = cleanEmail
        updatedDriver.phone = cleanPhone
        updatedDriver.licenseNumber = cleanLicenseNumber
        updatedDriver.isAvailable = isAvailable
        updatedDriver.vehicleCategories = vehicleCategories
        
        Task {
            do {
                let driver = try await driverManager.updateDriver(updatedDriver)
                
                DispatchQueue.main.async {
                    if let index = self.drivers.firstIndex(where: { $0.id == driver.id }) {
                        self.drivers[index] = driver
                    }
                    self.resetForm()
                    self.isShowingEditDriver = false
                    self.selectedDriver = nil
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update driver: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error updating driver: \(error)")
                }
            }
        }
    }
    
    /// Toggle the active status of a driver in Supabase
    func toggleDriverStatus(driver: Driver) {
        isLoading = true
        
        Task {
            do {
                let updatedDriver = try await driverManager.toggleDriverStatus(driverId: driver.id, isActive: !driver.isActive)
                
                DispatchQueue.main.async {
                    if let index = self.drivers.firstIndex(where: { $0.id == updatedDriver.id }) {
                        self.drivers[index] = updatedDriver
                    }
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update driver status: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error updating driver status: \(error)")
                }
            }
        }
    }
    
    /// Toggle the availability of a driver in Supabase
    func toggleDriverAvailability(driver: Driver) {
        isLoading = true
        
        Task {
            do {
                let updatedDriver = try await driverManager.toggleDriverAvailability(driverId: driver.id, isAvailable: !driver.isAvailable)
                
                DispatchQueue.main.async {
                    if let index = self.drivers.firstIndex(where: { $0.id == updatedDriver.id }) {
                        self.drivers[index] = updatedDriver
                    }
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update driver availability: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error updating driver availability: \(error)")
                }
            }
        }
    }
    
    /// Search for drivers based on search text
    func searchDrivers() {
        guard !searchText.isEmpty else {
            // If search is empty, just load all drivers
            fetchDrivers()
            return
        }
        
        // Only perform search if we have 3 or more characters
        guard searchText.count >= 3 else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Try to search on the backend first
                let searchResults = try await driverManager.searchDrivers(searchText: searchText)
                
                DispatchQueue.main.async {
                    self.drivers = searchResults
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error searching drivers: \(error)")
                    
                    // Fall back to local filtering if the remote search fails
                    let searchText = self.searchText.lowercased()
                    self.drivers = self.drivers.filter { driver in
                        driver.name.localizedCaseInsensitiveContains(searchText) ||
                        driver.id.localizedCaseInsensitiveContains(searchText) ||
                        driver.email.localizedCaseInsensitiveContains(searchText) ||
                        driver.licenseNumber.localizedCaseInsensitiveContains(searchText)
                    }
                }
            }
        }
    }
    
    // MARK: - UI Helper Methods
    
    func selectDriverForEdit(driver: Driver) {
        selectedDriver = driver
        name = driver.name
        email = driver.email
        phone = driver.phone
        licenseNumber = driver.licenseNumber
        isAvailable = driver.isAvailable
        vehicleCategories = driver.vehicleCategories
        isShowingEditDriver = true
    }
    
    func resetForm() {
        name = ""
        email = ""
        phone = ""
        licenseNumber = ""
        isAvailable = true
        vehicleCategories = []
        isShowingAddDriver = false
    }
    
    func getDriverById(_ id: String) -> Driver? {
        return drivers.first { $0.id == id }
    }
    
    // MARK: - Validation Methods
    
    // Validate if a phone number matches Indian format
    func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Indian phone numbers are typically 10 digits
        let phoneRegex = #"^\d{10}$"#
        return phoneNumber.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    // Validate if an email is properly formatted
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    // Validate if a license number is properly formatted
    func isValidLicenseNumber(_ licenseNumber: String) -> Bool {
        // Indian driving license format: typically two letters (state code) followed by numbers
        // Example: DL-0123456789 or DL0123456789 or MH 01 20210034567
        let licenseRegex = #"^[A-Z]{2}[-\s]?\d{2}[-\s]?\d{4}[-\s]?\d{7}$|^[A-Z]{2}[-\s]?\d{13}$"#
        return licenseNumber.range(of: licenseRegex, options: .regularExpression) != nil
    }
    
    // Check if entire driver form is valid
    func isDriverFormValid() -> Bool {
        // Name validation
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Driver name is required"
            return false
        }
        
        // Email validation
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Email address is required"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        // Phone validation
        if phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Phone number is required"
            return false
        }
        
        if !isValidPhoneNumber(phone) {
            errorMessage = "Please enter a valid 10-digit Indian phone number"
            return false
        }
        
        // License validation
        if licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "License number is required"
            return false
        }
        
        if !isValidLicenseNumber(licenseNumber) {
            errorMessage = "Please enter a valid Indian driving license number"
            return false
        }
        
        // Categories validation
        if vehicleCategories.isEmpty {
            errorMessage = "At least one vehicle category must be selected"
            return false
        }
        
        return true
    }
    
    // Static help text for driver fields
    static let licenseNumberHelpText = """
    Indian driving license format:
    • Format: [State Code][RTO Code][Year][Serial Number]
    • Example: MH 01 20210034567
    
    State codes are two letters (e.g., DL for Delhi, MH for Maharashtra)
    The RTO code is typically 1-2 digits
    The year is 4 digits
    The serial number is 7 digits
    """
    
    static let phoneNumberHelpText = """
    Indian phone number format:
    • Must be exactly 10 digits
    • Should not include the country code (+91)
    • Example: 9876543210
    """
} 
