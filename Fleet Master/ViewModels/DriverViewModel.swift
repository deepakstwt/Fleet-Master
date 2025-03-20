import Foundation
import SwiftUI

class DriverViewModel: ObservableObject {
    @Published var drivers: [Driver] = []
    @Published var searchText: String = ""
    @Published var isShowingAddDriver = false
    @Published var isShowingEditDriver = false
    @Published var selectedDriver: Driver?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var filterActive = true
    
    // Form properties
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var licenseNumber = ""
    @Published var isAvailable = true
    
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
        // For demo purposes, add some sample drivers
        addSampleDrivers()
    }
    
    func addSampleDrivers() {
        drivers = [
            Driver(name: "John Smith", email: "john.smith@fleet.com", phone: "555-123-4567", licenseNumber: "DL12345678"),
            Driver(name: "Jane Doe", email: "jane.doe@fleet.com", phone: "555-987-6543", licenseNumber: "DL87654321", isAvailable: false),
            Driver(name: "Robert Johnson", email: "robert.j@fleet.com", phone: "555-246-8135", licenseNumber: "DL13579246")
        ]
    }
    
    func addDriver() {
        let newDriver = Driver(
            name: name, 
            email: email, 
            phone: phone, 
            licenseNumber: licenseNumber,
            isAvailable: isAvailable
        )
        
        drivers.append(newDriver)
        resetForm()
        
        alertMessage = "Driver added successfully!\nID: \(newDriver.id)\nPassword: \(newDriver.password)"
        showAlert = true
    }
    
    func updateDriver() {
        guard let selectedDriver = selectedDriver,
              let index = drivers.firstIndex(where: { $0.id == selectedDriver.id }) else { return }
        
        drivers[index].name = name
        drivers[index].email = email
        drivers[index].phone = phone
        drivers[index].licenseNumber = licenseNumber
        drivers[index].isAvailable = isAvailable
        
        resetForm()
        isShowingEditDriver = false
        self.selectedDriver = nil
    }
    
    func toggleDriverStatus(driver: Driver) {
        guard let index = drivers.firstIndex(where: { $0.id == driver.id }) else { return }
        drivers[index].isActive.toggle()
    }
    
    func toggleDriverAvailability(driver: Driver) {
        guard let index = drivers.firstIndex(where: { $0.id == driver.id }) else { return }
        drivers[index].isAvailable.toggle()
    }
    
    func selectDriverForEdit(driver: Driver) {
        selectedDriver = driver
        name = driver.name
        email = driver.email
        phone = driver.phone
        licenseNumber = driver.licenseNumber
        isAvailable = driver.isAvailable
        isShowingEditDriver = true
    }
    
    func resetForm() {
        name = ""
        email = ""
        phone = ""
        licenseNumber = ""
        isAvailable = true
        isShowingAddDriver = false
    }
    
    func getDriverById(_ id: String) -> Driver? {
        return drivers.first { $0.id == id }
    }
} 