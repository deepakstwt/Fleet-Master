import SwiftUI

struct VehicleManagementView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @State private var isShowingDetail = false
    @State private var selectedVehicle: Vehicle?
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search and Filter Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search vehicles...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Active Only", isOn: $viewModel.filterActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .overlay(
                            Text("Active Only")
                                .font(.caption)
                                .offset(x: -45, y: -18)
                        )
                    
                    Button(action: {
                        viewModel.isShowingAddVehicle = true
                    }) {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                // Vehicle List
                List {
                    ForEach(viewModel.filteredVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, viewModel: viewModel)
                            .onTapGesture {
                                selectedVehicle = vehicle
                                isShowingDetail = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    viewModel.toggleVehicleStatus(vehicle: vehicle)
                                } label: {
                                    Label(vehicle.isActive ? "Retire" : "Activate", 
                                          systemImage: vehicle.isActive ? "car.fill.xmark" : "car.fill.checkmark")
                                }
                                .tint(vehicle.isActive ? .red : .green)
                                
                                Button {
                                    viewModel.selectVehicleForEdit(vehicle: vehicle)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Vehicle Management")
            .sheet(isPresented: $viewModel.isShowingAddVehicle) {
                AddVehicleView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditVehicle) {
                EditVehicleView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $isShowingDetail) {
                if let vehicle = selectedVehicle {
                    VehicleDetailView(vehicle: vehicle, viewModel: viewModel)
                }
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle
    let viewModel: VehicleViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 8) {
                Image(systemName: getFuelTypeIcon(vehicle.fuelType))
                    .font(.system(size: 14))
                    .padding(8)
                    .background(getFuelTypeColor(vehicle.fuelType).opacity(0.2))
                    .clipShape(Circle())
                
                Image(systemName: "car.fill")
                    .font(.system(size: 20))
                    .foregroundColor(vehicle.isActive ? .blue : .gray)
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.make) \(vehicle.model)")
                    .font(.headline)
                    .foregroundColor(vehicle.isActive ? .primary : .secondary)
                
                Text(vehicle.registrationNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("VIN: \(vehicle.vin)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(vehicle.year)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    // Documents status
                    Circle()
                        .fill(viewModel.areDocumentsValid(for: vehicle) ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("Docs")
                        .font(.caption)
                        .foregroundColor(viewModel.areDocumentsValid(for: vehicle) ? .green : .red)
                }
                
                Text(vehicle.isActive ? "Active" : "Retired")
                    .font(.caption)
                    .foregroundColor(vehicle.isActive ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(vehicle.isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(5)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func getFuelTypeIcon(_ fuelType: FuelType) -> String {
        switch fuelType {
        case .petrol: return "fuelpump.fill"
        case .diesel: return "fuelpump.fill"
        case .cng: return "leaf.fill"
        case .electric: return "bolt.fill"
        case .hybrid: return "bolt.car"
        }
    }
    
    private func getFuelTypeColor(_ fuelType: FuelType) -> Color {
        switch fuelType {
        case .petrol: return .orange
        case .diesel: return .yellow
        case .cng: return .green
        case .electric: return .blue
        case .hybrid: return .purple
        }
    }
}

struct AddVehicleView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Registration Number", text: $viewModel.registrationNumber)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Make", text: $viewModel.make)
                    TextField("Model", text: $viewModel.model)
                    
                    Stepper("Year: \(viewModel.year)", value: $viewModel.year, in: 1990...Calendar.current.component(.year, from: Date()) + 1)
                    
                    TextField("VIN", text: $viewModel.vin)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Color", text: $viewModel.color)
                    
                    Picker("Fuel Type", selection: $viewModel.selectedFuelType) {
                        ForEach(FuelType.allCases, id: \.self) { fuelType in
                            Text(fuelType.rawValue).tag(fuelType)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Documents & Certifications") {
                    DatePicker("RC Expiry Date", selection: $viewModel.rcExpiryDate, displayedComponents: .date)
                    
                    TextField("Insurance Number", text: $viewModel.insuranceNumber)
                    DatePicker("Insurance Expiry Date", selection: $viewModel.insuranceExpiryDate, displayedComponents: .date)
                    
                    TextField("Pollution Certificate Number", text: $viewModel.pollutionCertificateNumber)
                    DatePicker("Pollution Certificate Expiry", selection: $viewModel.pollutionCertificateExpiryDate, displayedComponents: .date)
                }
                
                Section("Service Information") {
                    DatePicker("Last Service Date", selection: Binding(
                        get: { viewModel.lastServiceDate ?? Date() },
                        set: { viewModel.lastServiceDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("Next Service Due", selection: Binding(
                        get: { viewModel.nextServiceDue ?? Date() },
                        set: { viewModel.nextServiceDue = $0 }
                    ), displayedComponents: .date)
                    
                    Stepper("Odometer: \(viewModel.currentOdometer) km", value: $viewModel.currentOdometer, in: 0...1000000, step: 100)
                }
                
                Section("Additional Notes") {
                    TextEditor(text: $viewModel.additionalNotes)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button("Add Vehicle") {
                        viewModel.addVehicle()
                        dismiss()
                    }
                    .disabled(viewModel.registrationNumber.isEmpty || viewModel.make.isEmpty || 
                             viewModel.model.isEmpty || viewModel.vin.isEmpty || viewModel.color.isEmpty)
                }
            }
            .navigationTitle("Add New Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditVehicleView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Registration Number", text: $viewModel.registrationNumber)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Make", text: $viewModel.make)
                    TextField("Model", text: $viewModel.model)
                    
                    Stepper("Year: \(viewModel.year)", value: $viewModel.year, in: 1990...Calendar.current.component(.year, from: Date()) + 1)
                    
                    TextField("VIN", text: $viewModel.vin)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Color", text: $viewModel.color)
                    
                    Picker("Fuel Type", selection: $viewModel.selectedFuelType) {
                        ForEach(FuelType.allCases, id: \.self) { fuelType in
                            Text(fuelType.rawValue).tag(fuelType)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Documents & Certifications") {
                    DatePicker("RC Expiry Date", selection: $viewModel.rcExpiryDate, displayedComponents: .date)
                    
                    TextField("Insurance Number", text: $viewModel.insuranceNumber)
                    DatePicker("Insurance Expiry Date", selection: $viewModel.insuranceExpiryDate, displayedComponents: .date)
                    
                    TextField("Pollution Certificate Number", text: $viewModel.pollutionCertificateNumber)
                    DatePicker("Pollution Certificate Expiry", selection: $viewModel.pollutionCertificateExpiryDate, displayedComponents: .date)
                }
                
                Section("Service Information") {
                    DatePicker("Last Service Date", selection: Binding(
                        get: { viewModel.lastServiceDate ?? Date() },
                        set: { viewModel.lastServiceDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("Next Service Due", selection: Binding(
                        get: { viewModel.nextServiceDue ?? Date() },
                        set: { viewModel.nextServiceDue = $0 }
                    ), displayedComponents: .date)
                    
                    Stepper("Odometer: \(viewModel.currentOdometer) km", value: $viewModel.currentOdometer, in: 0...1000000, step: 100)
                }
                
                Section("Additional Notes") {
                    TextEditor(text: $viewModel.additionalNotes)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button("Update Vehicle") {
                        viewModel.updateVehicle()
                        dismiss()
                    }
                    .disabled(viewModel.registrationNumber.isEmpty || viewModel.make.isEmpty || 
                             viewModel.model.isEmpty || viewModel.vin.isEmpty || viewModel.color.isEmpty)
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VehicleDetailView: View {
    let vehicle: Vehicle
    let viewModel: VehicleViewModel
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

#Preview {
    VehicleManagementView()
        .environmentObject(VehicleViewModel())
} 