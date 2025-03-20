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
    
    // Form properties
    @Published var registrationNumber = ""
    @Published var make = ""
    @Published var model = ""
    @Published var year = Calendar.current.component(.year, from: Date())
    @Published var vin = ""
    @Published var color = ""
    @Published var selectedFuelType = FuelType.petrol
    @Published var rcExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var insuranceNumber = ""
    @Published var insuranceExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var pollutionCertificateNumber = ""
    @Published var pollutionCertificateExpiryDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    @Published var lastServiceDate: Date? = Date()
    @Published var nextServiceDue: Date? = Date().addingTimeInterval(90*24*60*60) // 3 months from now
    @Published var currentOdometer = 0
    @Published var additionalNotes = ""
    
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
        // For demo purposes, add some sample vehicles
        addSampleVehicles()
    }
    
    func addSampleVehicles() {
        let oneYearFromNow = Date().addingTimeInterval(365*24*60*60)
        let threeMonthsFromNow = Date().addingTimeInterval(90*24*60*60)
        
        vehicles = [
            Vehicle(
                registrationNumber: "HR-01-AA-1234",
                make: "Toyota",
                model: "Camry",
                year: 2022,
                vin: "1HGCM82633A123456",
                color: "White",
                fuelType: .petrol,
                rcExpiryDate: oneYearFromNow,
                insuranceNumber: "INS-123456",
                insuranceExpiryDate: oneYearFromNow,
                pollutionCertificateNumber: "PC-123456",
                pollutionCertificateExpiryDate: oneYearFromNow,
                lastServiceDate: Date(),
                nextServiceDue: threeMonthsFromNow,
                currentOdometer: 5000
            ),
            Vehicle(
                registrationNumber: "DL-02-BB-5678",
                make: "Honda",
                model: "Civic",
                year: 2021,
                vin: "5YJSA1CP3DFP12345",
                color: "Black",
                fuelType: .diesel,
                rcExpiryDate: oneYearFromNow,
                insuranceNumber: "INS-654321",
                insuranceExpiryDate: oneYearFromNow,
                pollutionCertificateNumber: "PC-654321",
                pollutionCertificateExpiryDate: oneYearFromNow,
                lastServiceDate: Date().addingTimeInterval(-30*24*60*60), // 1 month ago
                nextServiceDue: threeMonthsFromNow,
                currentOdometer: 8000
            ),
            Vehicle(
                registrationNumber: "MH-03-CC-9012",
                make: "Hyundai",
                model: "Creta",
                year: 2023,
                vin: "KMHD84LF2JU123456",
                color: "Red",
                fuelType: .cng,
                rcExpiryDate: oneYearFromNow,
                insuranceNumber: "INS-901234",
                insuranceExpiryDate: oneYearFromNow,
                pollutionCertificateNumber: "PC-901234",
                pollutionCertificateExpiryDate: oneYearFromNow,
                lastServiceDate: Date().addingTimeInterval(-60*24*60*60), // 2 months ago
                nextServiceDue: Date().addingTimeInterval(30*24*60*60), // 1 month from now
                currentOdometer: 12000
            )
        ]
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
        
        vehicles.append(newVehicle)
        resetForm()
        
        alertMessage = "Vehicle added successfully!"
        showAlert = true
    }
    
    func updateVehicle() {
        guard let selectedVehicle = selectedVehicle,
              let index = vehicles.firstIndex(where: { $0.id == selectedVehicle.id }) else { return }
        
        vehicles[index].registrationNumber = registrationNumber
        vehicles[index].make = make
        vehicles[index].model = model
        vehicles[index].year = year
        vehicles[index].vin = vin
        vehicles[index].color = color
        vehicles[index].fuelType = selectedFuelType
        vehicles[index].rcExpiryDate = rcExpiryDate
        vehicles[index].insuranceNumber = insuranceNumber
        vehicles[index].insuranceExpiryDate = insuranceExpiryDate
        vehicles[index].pollutionCertificateNumber = pollutionCertificateNumber
        vehicles[index].pollutionCertificateExpiryDate = pollutionCertificateExpiryDate
        vehicles[index].lastServiceDate = lastServiceDate
        vehicles[index].nextServiceDue = nextServiceDue
        vehicles[index].currentOdometer = currentOdometer
        vehicles[index].additionalNotes = additionalNotes.isEmpty ? nil : additionalNotes
        
        resetForm()
        isShowingEditVehicle = false
        self.selectedVehicle = nil
    }
    
    func toggleVehicleStatus(vehicle: Vehicle) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index].isActive.toggle()
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
        rcExpiryDate = Date().addingTimeInterval(365*24*60*60)
        insuranceNumber = ""
        insuranceExpiryDate = Date().addingTimeInterval(365*24*60*60)
        pollutionCertificateNumber = ""
        pollutionCertificateExpiryDate = Date().addingTimeInterval(365*24*60*60)
        lastServiceDate = Date()
        nextServiceDue = Date().addingTimeInterval(90*24*60*60)
        currentOdometer = 0
        additionalNotes = ""
        isShowingAddVehicle = false
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