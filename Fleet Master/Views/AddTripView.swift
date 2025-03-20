import SwiftUI

struct AddTripView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRoutePreview = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Information") {
                    TextField("Trip Title", text: $tripViewModel.title)
                    
                    TextField("Start Location", text: $tripViewModel.startLocation)
                        .autocorrectionDisabled()
                    
                    TextField("End Location", text: $tripViewModel.endLocation)
                        .autocorrectionDisabled()
                    
                    if tripViewModel.isLoadingRoute {
                        HStack {
                            Spacer()
                            ProgressView("Calculating route...")
                            Spacer()
                        }
                    } else if let routeError = tripViewModel.routeError {
                        Text(routeError)
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if let routeInfo = tripViewModel.routeInformation {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                Text("Est. Distance: \(String(format: "%.1f", routeInfo.distance / 1000)) km")
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                Text("Est. Time: \(formatDuration(routeInfo.time))")
                            }
                            
                            Button(action: {
                                showRoutePreview = true
                            }) {
                                Text("Preview Route")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    DatePicker("Scheduled Start", selection: $tripViewModel.scheduledStartTime)
                    DatePicker("Scheduled End", selection: $tripViewModel.scheduledEndTime)
                    
                    if tripViewModel.routeInformation == nil {
                        HStack {
                            Text("Expected Distance (km)")
                            Spacer()
                            TextField("Distance", value: $tripViewModel.distance, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
                
                Section("Assignment (Optional)") {
                    Picker("Driver", selection: $tripViewModel.driverId) {
                        Text("Unassigned").tag(nil as String?)
                        ForEach(driverViewModel.availableDrivers) { driver in
                            Text(driver.name).tag(driver.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Vehicle", selection: $tripViewModel.vehicleId) {
                        Text("Unassigned").tag(nil as String?)
                        ForEach(vehicleViewModel.activeVehicles) { vehicle in
                            Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))").tag(vehicle.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Description") {
                    TextEditor(text: $tripViewModel.description)
                        .frame(minHeight: 100)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $tripViewModel.notes)
                        .frame(minHeight: 100)
                }
                
                Button("Schedule Trip") {
                    tripViewModel.addTrip()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Schedule Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tripViewModel.resetForm()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        tripViewModel.addTrip()
                    }
                }
            }
            .sheet(isPresented: $showRoutePreview) {
                NavigationStack {
                    TripMapView(startLocation: tripViewModel.startLocation, 
                               endLocation: tripViewModel.endLocation)
                        .edgesIgnoringSafeArea(.all)
                        .navigationTitle("Route Preview")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showRoutePreview = false
                                }
                            }
                            
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Use This Route") {
                                    tripViewModel.addRouteInfoToTrip()
                                    showRoutePreview = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

#Preview {
    AddTripView()
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 