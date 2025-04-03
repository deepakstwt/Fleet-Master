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
    
    // UI state
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                // Trip Information
                Section("TRIP INFORMATION") {
                    TextField("Trip Title", text: $title)
                    
                    TextField("Start Location", text: $startLocation)
                    
                    TextField("End Location", text: $endLocation)
                    
                    DatePicker("Scheduled Start", selection: $scheduledStartTime)
                    
                    DatePicker("Scheduled End", selection: $scheduledEndTime)
                    
                    Picker("Trip Status", selection: $tripStatus) {
                        ForEach(TripStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    
                    HStack {
                        Text("Expected Distance (km)")
                        Spacer()
                        TextField("Distance", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Description
                Section("DESCRIPTION") {
                    TextEditor(text: $tripDescription)
                        .frame(minHeight: 100)
                }
                
                // Notes
                Section("NOTES (OPTIONAL)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                // Assignment
                Section("ASSIGNMENT") {
                    Picker("Assigned Driver", selection: $driverId) {
                        Text("Unassigned").tag(nil as String?)
                        
                        ForEach(driverViewModel.availableDrivers) { driver in
                            Text(driver.name).tag(driver.id as String?)
                        }
                    }
                    
                    Picker("Assigned Vehicle", selection: $vehicleId) {
                        Text("Unassigned").tag(nil as String?)
                        
                        ForEach(vehicleViewModel.activeVehicles) { vehicle in
                            Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))").tag(vehicle.id as String?)
                        }
                    }
                }
                
                // Update Button
                Section {
                    Button("Update Trip") {
                        Task {
                            await updateTrip()
                        }
                    }
                    .disabled(title.isEmpty || 
                              startLocation.isEmpty || 
                              endLocation.isEmpty ||
                              tripDescription.isEmpty ||
                              isUpdating)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tripViewModel.selectedTrip = selectedTrip
            }
            .alert("Error Updating Trip", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                        Text("Updating trip...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemGray4).opacity(0.9))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Data Handling
    
    private func updateTrip() async {
        isUpdating = true
        
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
        
        do {
            // Create updated trip directly
            let updatedTrip = Trip(
                id: selectedTrip.id, 
                title: title, 
                startLocation: startLocation, 
                endLocation: endLocation, 
                scheduledStartTime: scheduledStartTime, 
                scheduledEndTime: scheduledEndTime, 
                status: tripStatus, 
                driverId: driverId, 
                vehicleId: vehicleId, 
                description: tripDescription,
                distance: distance,
                actualStartTime: selectedTrip.actualStartTime, 
                actualEndTime: selectedTrip.actualEndTime, 
                notes: notes.isEmpty ? nil : notes,
                routeInfo: selectedTrip.routeInfo
            )
            
            // Update directly using TripSupabaseManager
            let updated = try await TripSupabaseManager.shared.updateTrip(updatedTrip)
            
            // Update the viewModel's local data
            await MainActor.run {
                // Find and update the trip in the trips array
                if let index = tripViewModel.trips.firstIndex(where: { $0.id == updated.id }) {
                    tripViewModel.trips[index] = updated
                }
                
                // Refresh the trip list to ensure UI updates properly
                Task {
                    await tripViewModel.loadTrips()
                }
                
                tripViewModel.resetForm()
                tripViewModel.isShowingEditTrip = false
                isUpdating = false
                
                // Dismiss this sheet
                dismiss()
            }
        } catch {
            await MainActor.run {
                isUpdating = false
                errorMessage = "Failed to update trip: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    let trip = Trip.previewTrip
    return EditTripView(selectedTrip: trip)
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 