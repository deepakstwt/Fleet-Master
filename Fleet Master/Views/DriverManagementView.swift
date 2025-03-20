import SwiftUI

struct DriverManagementView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @State private var isShowingDetail = false
    @State private var selectedDriver: Driver?
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search and Filter Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search drivers...", text: $viewModel.searchText)
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
                        viewModel.isShowingAddDriver = true
                    }) {
                        Label("Add Driver", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                // Driver List
                List {
                    ForEach(viewModel.filteredDrivers) { driver in
                        DriverRow(driver: driver)
                            .onTapGesture {
                                selectedDriver = driver
                                isShowingDetail = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    viewModel.toggleDriverAvailability(driver: driver)
                                } label: {
                                    Label(driver.isAvailable ? "Set Unavailable" : "Set Available", 
                                          systemImage: driver.isAvailable ? "person.crop.circle.badge.xmark.fill" : "person.crop.circle.badge.checkmark.fill")
                                }
                                .tint(driver.isAvailable ? .orange : .green)
                                
                                Button {
                                    viewModel.toggleDriverStatus(driver: driver)
                                } label: {
                                    Label(driver.isActive ? "Disable" : "Enable", 
                                          systemImage: driver.isActive ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.checkmark")
                                }
                                .tint(driver.isActive ? .red : .green)
                                
                                Button {
                                    viewModel.selectDriverForEdit(driver: driver)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Driver Management")
            .sheet(isPresented: $viewModel.isShowingAddDriver) {
                AddDriverView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditDriver) {
                EditDriverView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $isShowingDetail) {
                if let driver = selectedDriver {
                    DriverDetailView(driver: driver)
                }
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

struct DriverRow: View {
    let driver: Driver
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(driver.isActive ? (driver.isAvailable ? .blue : .orange) : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                    .foregroundColor(driver.isActive ? .primary : .secondary)
                
                Text("ID: \(driver.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(driver.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("License")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(driver.licenseNumber)
                    .font(.subheadline)
                
                HStack(spacing: 6) {
                    if driver.isActive {
                        Text(driver.isAvailable ? "Available" : "Unavailable")
                            .font(.caption)
                            .foregroundColor(driver.isAvailable ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(driver.isAvailable ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .cornerRadius(5)
                    } else {
                        Text("Inactive")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(5)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddDriverView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Driver Information") {
                    TextField("Full Name", text: $viewModel.name)
                        .textContentType(.name)
                    
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    TextField("Phone", text: $viewModel.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("License Information") {
                    TextField("License Number", text: $viewModel.licenseNumber)
                }
                
                Section("Status") {
                    Toggle("Available for Trips", isOn: $viewModel.isAvailable)
                }
                
                Section {
                    Button("Add Driver") {
                        viewModel.addDriver()
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty || viewModel.email.isEmpty || 
                             viewModel.phone.isEmpty || viewModel.licenseNumber.isEmpty)
                }
            }
            .navigationTitle("Add New Driver")
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

struct EditDriverView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Driver Information") {
                    TextField("Full Name", text: $viewModel.name)
                        .textContentType(.name)
                    
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    TextField("Phone", text: $viewModel.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("License Information") {
                    TextField("License Number", text: $viewModel.licenseNumber)
                }
                
                Section("Status") {
                    Toggle("Available for Trips", isOn: $viewModel.isAvailable)
                }
                
                Section {
                    Button("Update Driver") {
                        viewModel.updateDriver()
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty || viewModel.email.isEmpty || 
                             viewModel.phone.isEmpty || viewModel.licenseNumber.isEmpty)
                }
            }
            .navigationTitle("Edit Driver")
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

struct DriverDetailView: View {
    let driver: Driver
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Personal Information") {
                    DriverDetailRow(title: "Full Name", value: driver.name)
                    DriverDetailRow(title: "Email", value: driver.email)
                    DriverDetailRow(title: "Phone", value: driver.phone)
                }
                
                Section("Driver Information") {
                    DriverDetailRow(title: "ID", value: driver.id)
                    DriverDetailRow(title: "License Number", value: driver.licenseNumber)
                    DriverDetailRow(title: "Account Status", value: driver.isActive ? "Active" : "Inactive")
                    DriverDetailRow(title: "Availability Status", value: driver.isAvailable ? "Available" : "Unavailable")
                    DriverDetailRow(title: "Hire Date", value: formatDate(driver.hireDate))
                }
            }
            .navigationTitle("Driver Details")
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

struct DriverDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DriverManagementView()
        .environmentObject(DriverViewModel())
} 