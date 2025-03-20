import SwiftUI

struct AssignDriverView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDriverId: String?
    @State private var selectedVehicleId: String?
    
    let selectedTrip: Trip
    
    init(selectedTrip: Trip) {
        self.selectedTrip = selectedTrip
        _selectedDriverId = State(initialValue: selectedTrip.driverId)
        _selectedVehicleId = State(initialValue: selectedTrip.vehicleId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    Text(selectedTrip.title)
                        .font(.headline)
                    
                    HStack {
                        Text("From:")
                            .fontWeight(.semibold)
                        Text(selectedTrip.startLocation)
                    }
                    
                    HStack {
                        Text("To:")
                            .fontWeight(.semibold)
                        Text(selectedTrip.endLocation)
                    }
                    
                    HStack {
                        Text("When:")
                            .fontWeight(.semibold)
                        Text("\(formatDate(selectedTrip.scheduledStartTime)) to \(formatDate(selectedTrip.scheduledEndTime))")
                    }
                }
                
                Section("Select Driver") {
                    if driverViewModel.availableDrivers.isEmpty {
                        Text("No available drivers found")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(driverViewModel.availableDrivers) { driver in
                            Button(action: {
                                selectedDriverId = driver.id
                            }) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(driver.name)
                                            .foregroundColor(.primary)
                                        
                                        Text(driver.licenseNumber)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedDriverId == driver.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
                
                Section("Select Vehicle") {
                    if vehicleViewModel.activeVehicles.isEmpty {
                        Text("No active vehicles available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(vehicleViewModel.activeVehicles) { vehicle in
                            Button(action: {
                                selectedVehicleId = vehicle.id
                            }) {
                                HStack {
                                    Image(systemName: "car.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text("\(vehicle.make) \(vehicle.model)")
                                            .foregroundColor(.primary)
                                        
                                        Text(vehicle.registrationNumber)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedVehicleId == vehicle.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
                
                Section {
                    Button("Assign") {
                        assignDriverAndVehicle()
                        dismiss()
                    }
                    .disabled(selectedDriverId == nil || selectedVehicleId == nil)
                }
            }
            .navigationTitle("Assign Driver & Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func assignDriverAndVehicle() {
        // Call TripViewModel to update the assignment
        tripViewModel.assignDriver(to: selectedTrip, driverId: selectedDriverId, vehicleId: selectedVehicleId)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    let trip = Trip.previewTrip
    return AssignDriverView(selectedTrip: trip)
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 