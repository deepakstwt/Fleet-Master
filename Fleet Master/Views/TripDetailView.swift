import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showMap = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Trip Information") {
                    detailRow(title: "Status", value: trip.status.rawValue)
                    detailRow(title: "Title", value: trip.title)
                    detailRow(title: "Description", value: trip.description)
                }
                
                Section("Schedule") {
                    detailRow(title: "Start Date", value: formatDate(trip.scheduledStartTime))
                    detailRow(title: "End Date", value: formatDate(trip.scheduledEndTime))
                    
                    if let actualStart = trip.actualStartTime {
                        detailRow(title: "Actual Start", value: formatDate(actualStart))
                    }
                    
                    if let actualEnd = trip.actualEndTime {
                        detailRow(title: "Actual End", value: formatDate(actualEnd))
                    }
                }
                
                Section("Locations") {
                    detailRow(title: "Start", value: trip.startLocation)
                    detailRow(title: "Destination", value: trip.endLocation)
                    
                    if let distance = trip.distance {
                        detailRow(title: "Distance", value: "\(String(format: "%.1f", distance)) km")
                    }
                    
                    Button(action: {
                        showMap = true
                    }) {
                        Label("View Route", systemImage: "map")
                    }
                }
                
                Section("Assignment") {
                    let driverName = trip.driverId != nil ? 
                        (driverViewModel.getDriverById(trip.driverId!)?.name ?? "Unknown") : "Unassigned"
                    detailRow(title: "Driver", value: driverName)
                    
                    let vehicleName = trip.vehicleId != nil ? 
                        formatVehicle(vehicleViewModel.getVehicleById(trip.vehicleId!)) : "Unassigned"
                    detailRow(title: "Vehicle", value: vehicleName)
                }
                
                if let notes = trip.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMap) {
                NavigationStack {
                    if #available(iOS 17.0, *) {
                        TripMapView(startLocation: trip.startLocation, endLocation: trip.endLocation)
                            .navigationTitle("Trip Route")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Close") {
                                        showMap = false
                                    }
                                }
                            }
                    } else {
                        // Fallback for iOS 16 and earlier
                        Text("Map view not available")
                            .navigationTitle("Trip Route")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Close") {
                                        showMap = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatVehicle(_ vehicle: Vehicle?) -> String {
        guard let vehicle = vehicle else { return "Unknown" }
        return "\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))"
    }
}

#Preview {
    let trip = Trip.previewTrip
    return TripDetailView(trip: trip)
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 
