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
        isLoading = true
        
        let newDriver = Driver(
            name: name, 
            email: email, 
            phone: phone, 
            licenseNumber: licenseNumber,
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
        isLoading = true
        
        var updatedDriver = selectedDriver
        updatedDriver.name = name
        updatedDriver.email = email
        updatedDriver.phone = phone
        updatedDriver.licenseNumber = licenseNumber
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
} 
