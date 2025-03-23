import SwiftUI

struct VehicleDetailView: View {
    let vehicle: Vehicle
    @StateObject private var viewModel: VehicleViewModel = VehicleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Vehicle Information") {
                    DetailRow(title: "Registration Number", value: vehicle.registrationNumber)
                    DetailRow(title: "Make & Model", value: "\(vehicle.make) \(vehicle.model)")
                    DetailRow(title: "Year", value: "\(vehicle.year)")
                    DetailRow(title: "VIN", value: vehicle.vin)
                    DetailRow(title: "Color", value: vehicle.color)
                    DetailRow(title: "Fuel Type", value: vehicle.fuelType.rawValue)
                    DetailRow(title: "Status", value: vehicle.isActive ? "Active" : "Retired")
                }
                
                Section("Document Information") {
                    DetailRow(title: "RC Expiry Date", value: formatDate(vehicle.rcExpiryDate))
                    DetailRow(title: "Insurance Number", value: vehicle.insuranceNumber)
                    DetailRow(title: "Insurance Expiry Date", value: formatDate(vehicle.insuranceExpiryDate))
                    DetailRow(title: "Pollution Certificate", value: vehicle.pollutionCertificateNumber)
                    DetailRow(title: "Pollution Certificate Expiry", value: formatDate(vehicle.pollutionCertificateExpiryDate))
                }
                
                Section("Service Information") {
                    if let lastServiceDate = vehicle.lastServiceDate {
                        DetailRow(title: "Last Service Date", value: formatDate(lastServiceDate))
                    }
                    
                    if let nextServiceDue = vehicle.nextServiceDue {
                        DetailRow(title: "Next Service Due", value: formatDate(nextServiceDue))
                        
                        if viewModel.isServiceDue(for: vehicle) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Service Overdue")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    DetailRow(title: "Current Odometer", value: "\(vehicle.currentOdometer) km")
                }
                
                if let notes = vehicle.additionalNotes, !notes.isEmpty {
                    Section("Additional Notes") {
                        Text(notes)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

