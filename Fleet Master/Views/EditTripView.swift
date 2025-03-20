import SwiftUI

struct EditTripView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    
    let selectedTrip: Trip
    
    // Form fields
    @State private var title: String = ""
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var scheduledStartTime: Date = Date()
    @State private var scheduledEndTime: Date = Date()
    @State private var tripStatus: TripStatus = .scheduled
    @State private var tripDescription: String = ""
    @State private var notes: String = ""
    @State private var distance: Double?
    @State private var driverId: String?
    @State private var vehicleId: String?
    
    init(selectedTrip: Trip) {
        self.selectedTrip = selectedTrip
        _title = State(initialValue: selectedTrip.title)
        _startLocation = State(initialValue: selectedTrip.startLocation)
        _endLocation = State(initialValue: selectedTrip.endLocation)
        _scheduledStartTime = State(initialValue: selectedTrip.scheduledStartTime)
        _scheduledEndTime = State(initialValue: selectedTrip.scheduledEndTime)
        _tripStatus = State(initialValue: selectedTrip.status)
        _tripDescription = State(initialValue: selectedTrip.description)
        _notes = State(initialValue: selectedTrip.notes ?? "")
        _distance = State(initialValue: selectedTrip.distance)
        _driverId = State(initialValue: selectedTrip.driverId)
        _vehicleId = State(initialValue: selectedTrip.vehicleId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Information") {
                    TextField("Trip Title", text: $title)
                    
                    TextField("Start Location", text: $startLocation)
                    TextField("End Location", text: $endLocation)
                    
                    DatePicker("Scheduled Start", selection: $scheduledStartTime)
                    DatePicker("Scheduled End", selection: $scheduledEndTime)
                    
                    Picker("Status", selection: $tripStatus) {
                        ForEach(TripStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("Expected Distance (km)")
                        Spacer()
                        TextField("Distance", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("Description") {
                    TextEditor(text: $tripDescription)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section("Assignment") {
                    Picker("Driver", selection: $driverId) {
                        Text("Unassigned").tag(nil as String?)
                        
                        ForEach(driverViewModel.availableDrivers) { driver in
                            Text(driver.name).tag(driver.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Vehicle", selection: $vehicleId) {
                        Text("Unassigned").tag(nil as String?)
                        
                        ForEach(vehicleViewModel.activeVehicles) { vehicle in
                            Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))").tag(vehicle.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    Button("Update Trip") {
                        prepareAndUpdateTrip()
                        dismiss()
                    }
                    .disabled(title.isEmpty || 
                              startLocation.isEmpty || 
                              endLocation.isEmpty ||
                              tripDescription.isEmpty)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Set the selected trip for editing in the view model
                tripViewModel.selectedTrip = selectedTrip
            }
        }
    }
    
    private func prepareAndUpdateTrip() {
        // Transfer form data to view model
        tripViewModel.title = title
        tripViewModel.startLocation = startLocation
        tripViewModel.endLocation = endLocation
        tripViewModel.scheduledStartTime = scheduledStartTime
        tripViewModel.scheduledEndTime = scheduledEndTime
        tripViewModel.status = tripStatus
        tripViewModel.description = tripDescription
        tripViewModel.notes = notes
        tripViewModel.distance = distance
        tripViewModel.driverId = driverId
        tripViewModel.vehicleId = vehicleId
        
        // Call TripViewModel to update the trip
        tripViewModel.updateTrip()
    }
}

#Preview {
    let trip = Trip.previewTrip
    return EditTripView(selectedTrip: trip)
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 