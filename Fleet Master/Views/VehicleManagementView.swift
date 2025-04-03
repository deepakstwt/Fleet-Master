import SwiftUI
// Make sure to only use these types from their proper files
// MaintenanceViewModel and MaintenancePersonnel are from their respective files
// VehicleMaintenanceViewModel and TechnicianData are local to this file

struct VehicleManagementView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @State private var searchText = ""
    @State private var showAddVehicleSheet = false
    @State private var showEditVehicleSheet = false
    @State private var selectedVehicle: Vehicle?
    @State private var selectedSortOption: SortOption = .newest
    @State private var showFilterMenu = false
    @State private var selectedVehicleTypeFilter: VehicleType?
    @State private var showActiveOnly = true
    @State private var selectedStatusFilter: VehicleStatus?
    
    enum SortOption {
        case newest, oldest, makeAsc, makeDesc
    }
    
    enum VehicleStatus: String {
        case available = "Available"
        case underMaintenance = "Under Maintenance"
        case onTrip = "On Trip"
        case idle = "Idle"
    }
    
    private var sortedVehicles: [Vehicle] {
        let filteredVehicles = viewModel.vehicles.filter { vehicle in
            // Filter by vehicle type if selected
            if let typeFilter = selectedVehicleTypeFilter, vehicle.vehicleType != typeFilter {
                return false
            }
            
            // Filter by status if selected
            if let statusFilter = selectedStatusFilter {
                switch statusFilter {
                case .available:
                    // Available means the vehicle is active and not due for service
                    if !vehicle.isActive || (vehicle.nextServiceDue ?? Date.distantFuture) <= Date() {
                        return false
                    }
                case .underMaintenance:
                    // Under maintenance means the vehicle is due for service
                    if (vehicle.nextServiceDue ?? Date.distantFuture) > Date() {
                        return false
                    }
                case .onTrip:
                    // For now, we'll consider a vehicle on trip if it's active
                    // This should be updated once trip tracking is implemented
                    if !vehicle.isActive {
                        return false
                    }
                case .idle:
                    // Idle means active but not due for service
                    if !vehicle.isActive || (vehicle.nextServiceDue ?? Date.distantFuture) <= Date() {
                        return false
                    }
                }
            }
            
            // Filter by active status
            if showActiveOnly && !vehicle.isActive {
                return false
            }
            
            // Filter by search text
            if !searchText.isEmpty {
                let searchQuery = searchText.lowercased()
                return vehicle.make.lowercased().contains(searchQuery) ||
                       vehicle.model.lowercased().contains(searchQuery) ||
                       vehicle.registrationNumber.lowercased().contains(searchQuery) ||
                       vehicle.vin.lowercased().contains(searchQuery)
            }
            
            return true
        }
        
        switch selectedSortOption {
        case .newest:
            return filteredVehicles.sorted(by: { $0.year > $1.year })
        case .oldest:
            return filteredVehicles.sorted(by: { $0.year < $1.year })
        case .makeAsc:
            return filteredVehicles.sorted(by: { $0.make < $1.make })
        case .makeDesc:
            return filteredVehicles.sorted(by: { $0.make > $1.make })
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and filter bar
                    searchAndFilterBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 3)
                        )
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else if sortedVehicles.isEmpty {
                emptyStateView
            } else {
                vehicleListView
            }
        }
            }
        .navigationTitle("Vehicle Management")
            .sheet(isPresented: $showAddVehicleSheet) {
            AddVehicleView()
        }
            .sheet(item: $selectedVehicle) { vehicle in
            EditVehicleView()
                .environmentObject(viewModel)
                    .onAppear {
                        viewModel.selectVehicleForEdit(vehicle: vehicle)
                    }
            }
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await viewModel.searchVehiclesInDatabase()
                }
            }
            .refreshable {
                Task {
                    await viewModel.fetchVehicles()
                }
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
        }
        }
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search bar and menu buttons
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by make, model, or registration", text: $searchText)
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Menu {
                    Button {
                        selectedSortOption = .newest
                    } label: {
                        Label("Newest First", systemImage: "arrow.down")
                            .foregroundColor(selectedSortOption == .newest ? .blue : .primary)
                    }
                    
                    Button {
                        selectedSortOption = .oldest
                    } label: {
                        Label("Oldest First", systemImage: "arrow.up")
                            .foregroundColor(selectedSortOption == .oldest ? .blue : .primary)
                    }
                    
                    Button {
                        selectedSortOption = .makeAsc
                    } label: {
                        Label("Make (A-Z)", systemImage: "arrow.up")
                            .foregroundColor(selectedSortOption == .makeAsc ? .blue : .primary)
                    }
                    
                    Button {
                        selectedSortOption = .makeDesc
                    } label: {
                        Label("Make (Z-A)", systemImage: "arrow.down")
                            .foregroundColor(selectedSortOption == .makeDesc ? .blue : .primary)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                // Add vehicle button
                Button(action: {
                    showAddVehicleSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterButton(title: "All", status: nil, icon: "car.fill", color: .gray)
                    filterButton(title: "Available", status: .available, icon: "checkmark.circle.fill", color: .green)
                    filterButton(title: "Under Maintenance", status: .underMaintenance, icon: "wrench.fill", color: .orange)
                    filterButton(title: "On Trip", status: .onTrip, icon: "car.side.fill", color: .blue)
                    filterButton(title: "Idle", status: .idle, icon: "car.circle.fill", color: .gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    private func filterButton(title: String, status: VehicleStatus?, icon: String, color: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                if selectedStatusFilter == status {
                    selectedStatusFilter = nil
                } else {
                    selectedStatusFilter = status
                }
            }
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(selectedStatusFilter == status ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedStatusFilter == status ? Color.accentColor : Color(.systemGray6))            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedStatusFilter == status ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var filterView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Filter buttons
                VStack(spacing: 12) {
                    // Available button
                    Button {
                        selectedVehicleTypeFilter = nil
                        showActiveOnly = true
                        showFilterMenu = false
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Available")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Under Maintenance button
                    Button {
                        selectedVehicleTypeFilter = nil
                        showActiveOnly = false
                        showFilterMenu = false
                    } label: {
                        HStack {
                            Image(systemName: "wrench.fill")
                                .foregroundColor(.orange)
                            Text("Under Maintenance")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // On Trip button
                    Button {
                        selectedVehicleTypeFilter = nil
                        showActiveOnly = true
                        showFilterMenu = false
                    } label: {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.blue)
                            Text("On Trip")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Idle button
                    Button {
                        selectedVehicleTypeFilter = nil
                        showActiveOnly = true
                        showFilterMenu = false
                    } label: {
                        HStack {
                            Image(systemName: "car.side.fill")
                                .foregroundColor(.gray)
                            Text("Idle")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilterMenu = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Loading vehicles...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 16)
            Spacer()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await viewModel.fetchVehicles()
                }
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.fill")
                .font(.system(size: 70))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            
            if viewModel.vehicles.isEmpty {
                Text("No Vehicles Found")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add your first vehicle to the fleet by tapping the + button.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    showAddVehicleSheet = true
                }) {
                    Text("Add Vehicle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            } else {
                Text("No Matching Vehicles")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(showActiveOnly ?
                     "No active vehicles match your search. Try adjusting your filter settings or including inactive vehicles." :
                     "No vehicles match your search criteria. Try adjusting your filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    showActiveOnly = false
                    selectedVehicleTypeFilter = nil
                    searchText = ""
                }) {
                    Text("Clear Filters")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
    }
    
    private var vehicleListView: some View {
        VStack(spacing: 0) {
            // Column Headers (Fixed header)
            HStack(spacing: 0) {
                // Vehicle Info Column (with icon space)
                HStack(spacing: 8) {
                    // Space for icon
                    Spacer()
                        .frame(width: 60)
                    
                    Text("Vehicle Info")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    Button {
                        withAnimation {
                            if selectedSortOption == .makeAsc {
                                selectedSortOption = .makeDesc
                            } else {
                                selectedSortOption = .makeAsc
                            }
                        }
                    } label: {
                        Image(systemName: selectedSortOption == .makeDesc ? "arrow.down" : "arrow.up")
                            .font(.caption)
                            .foregroundStyle(selectedSortOption == .makeAsc || selectedSortOption == .makeDesc ? .blue : .secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                
                // Type column
                Text("Type")
                    .font(.subheadline.bold())
                    .frame(width: 80, alignment: .center)
                    .layoutPriority(1)
                
                // Year column with sort button
                HStack(spacing: 4) {
                    Text("Year")
                        .font(.subheadline.bold())
                    
                    Button {
                        withAnimation {
                            if selectedSortOption == .newest {
                                selectedSortOption = .oldest
                            } else {
                                selectedSortOption = .newest
                            }
                        }
                    } label: {
                        Image(systemName: selectedSortOption == .oldest ? "arrow.down" : "arrow.up")
                            .font(.caption)
                            .foregroundStyle(selectedSortOption == .newest || selectedSortOption == .oldest ? .blue : .secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .frame(width: 70, alignment: .center)
                .layoutPriority(1)
                
                // Status column
                Text("Status")
                    .font(.subheadline.bold())
                    .frame(width: 80, alignment: .center)
                    .layoutPriority(1)
                
                // Actions column
                Text("Actions")
                    .font(.subheadline.bold())
                    .frame(width: 80, alignment: .center)
                    .layoutPriority(1)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Rectangle()
                        .fill(Color(.systemBackground))
                    
                    // Bottom border for the header
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            
            // Table content
        ScrollView {
                LazyVStack(spacing: 0) {
                ForEach(sortedVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, onEdit: {
                            viewModel.selectVehicleForEdit(vehicle: vehicle)
                            selectedVehicle = vehicle
                        }, onToggleStatus: {
                            viewModel.toggleVehicleStatus(vehicle: vehicle)
                        }, onTap: {
                            selectedVehicle = vehicle
                        })
                        .id(vehicle.id)
                    }
                    
                    if sortedVehicles.count > 0 {
                        // Pagination and summary footer
                        HStack {
                            Text("Showing \(sortedVehicles.count) vehicles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                            Button {
                                    // Previous page
                            } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Previous")
                                    }
                                    .font(.caption)
                                }
                                .disabled(true)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                                
                                Text("Page 1")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            
                            Button {
                                    // Next page
                            } label: {
                                    HStack(spacing: 4) {
                                        Text("Next")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.caption)
                                }
                                .disabled(true)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                        .padding(16)
                        .background(
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: -1)
                        )
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle
    let onEdit: () -> Void
    let onToggleStatus: () -> Void
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Vehicle info column
                HStack(spacing: 12) {
            // Avatar/Icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.15))
                            .frame(width: 48, height: 48)
                
                Image(systemName: vehicle.vehicleType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
            }
            
            // Vehicle Info
                    VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.make) \(vehicle.model)")
                            .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(vehicle.isActive ? .primary : .secondary)
                            .lineLimit(1)
                
                Text(vehicle.registrationNumber)
                            .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("VIN: \(vehicle.vin)")
                            .font(.caption2)
                    .foregroundColor(.secondary)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                
                // Type column
                    VehicleTypeBadge(type: vehicle.vehicleType)
                    .frame(width: 80, alignment: .center)
                    .layoutPriority(1)
                
                // Year column - Display without commas
                Text(String(format: "%d", vehicle.year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .center)
                    .layoutPriority(1)
                
                // Status column
                CommonStatusBadge(text: statusText, color: statusColor)
                    .frame(width: 80, alignment: .center)
                    .layoutPriority(1)
                
                // Actions column
                HStack(spacing: 16) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: onToggleStatus) {
                        Image(systemName: vehicle.isActive ? "trash" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(vehicle.isActive ? .red : .green)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .opacity(isHovered ? 1 : 0.6)
                .frame(width: 80, alignment: .center)
                .layoutPriority(1)
            }
        .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                Color(isHovered ? .systemGray6 : .systemBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .overlay(
            Divider()
                .opacity(0.5),
            alignment: .bottom
        )
    }
    
    private var statusText: String {
        if !vehicle.isActive {
            return "Inactive"
        } else {
            return "Active"
        }
    }
    
    private var statusColor: Color {
        if !vehicle.isActive {
            return .red
        } else {
            return .green
        }
    }
}

struct VehicleTypeBadge: View {
    let type: VehicleType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10))
                .foregroundColor(badgeColor)
            
            Text(type.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(badgeColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(badgeColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var badgeColor: Color {
        switch type {
        case .lmvTr:
            return .blue
        case .mgv:
            return .green
        case .hmv, .htv:
            return .purple
        case .hpmv:
            return .orange
        case .hgmv:
            return .cyan
        case .trans:
            return .teal
        case .psv:
            return .indigo
        }
    }
}

// Add this extension for better spacing constants
extension CGFloat {
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
}

struct AddVehicleView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var showingHelp = false
    @FocusState private var focusField: FormField?
    
    enum FormField {
        case registration, make, model, vin, color, insuranceNumber, pollutionNumber
    }
    
    // Helper function for read-only fields
    private func readOnlyField(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(value)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // Helper function for input fields
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType,
        field: FormField,
        errorMessage: String?,
        autocapitalization: TextInputAutocapitalization = .characters
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(autocapitalization)
                    .focused($focusField, equals: field)
                    .onSubmit {
                        advanceToNextField(from: field)
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(errorMessage != nil ? Color.red : focusField == field ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
            )
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }
    
    private func helpItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    enum FormStep: Int, CaseIterable, Identifiable {
        case basic = 0
        case documents = 1
        case service = 2
        
        var id: Int { self.rawValue }
        
        var title: String {
            switch self {
            case .basic: return "Basic Information"
            case .documents: return "Documents & Certifications"
            case .service: return "Service Information"
            }
        }
        
        var icon: String {
            switch self {
            case .basic: return "car.fill"
            case .documents: return "doc.text.fill"
            case .service: return "wrench.and.screwdriver.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { step in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("\(step)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(stepTitle(for: step))
                                .font(.caption)
                                .foregroundStyle(step == currentStep ? Color.primary : Color.secondary)
                        }
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                
                // Form content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch currentStep {
                        case 1:
                            basicInfoSection
                                .transition(.opacity)
                        case 2:
                            documentsSection
                                .transition(.opacity)
                        case 3:
                            serviceInfoSection
                                .transition(.opacity)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Bottom navigation
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                    }
                    
                    if currentStep < 3 {
                        Button(action: {
                            withAnimation {
                                if currentStep == 1 && isStep1Valid {
                                    currentStep += 1
                                } else if currentStep == 2 && isStep2Valid {
                                    currentStep += 1
                                }
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (currentStep == 1 && isStep1Valid) || (currentStep == 2 && isStep2Valid)
                                ? Color.blue
                                : Color.blue.opacity(0.3)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled((currentStep == 1 && !isStep1Valid) || (currentStep == 2 && !isStep2Valid))
                    } else {
                        Button(action: {
                            viewModel.addVehicle()
                            dismiss()
                        }) {
                            Text("Add Vehicle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.blue : Color.blue.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(!isFormValid)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add New Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingHelp.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Adding a New Vehicle")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        helpItem(icon: "1.circle.fill", title: "Basic Information",
                                description: "Enter the vehicle's registration, make, model, and other basic details.")
                        
                        helpItem(icon: "2.circle.fill", title: "Documents",
                                description: "Enter details about RC, insurance, and pollution certificates.")
                        
                        helpItem(icon: "3.circle.fill", title: "Service Information",
                                description: "Add service history and odometer reading for maintenance tracking.")
                    }
                    
                    Spacer()
                    
                    Button {
                        showingHelp = false
                    } label: {
                        Text("Got It")
                    .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(24)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusField = .registration
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Vehicle Details")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Enter the vehicle's registration information and basic details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                
            // Registration Number - Editable
            inputField(
                title: "Registration Number",
                placeholder: "Enter vehicle registration number",
                text: $viewModel.registrationNumber,
                icon: "car.fill",
                keyboardType: .default,
                field: .registration,
                errorMessage: viewModel.registrationNumber.isEmpty ? "Registration number is required" :
                              viewModel.registrationNumber.count < 4 ? "Registration number must be at least 4 characters" : nil,
                autocapitalization: .characters
            )
            
            // Make - Editable
            inputField(
                title: "Make",
                placeholder: "Enter vehicle manufacturer",
                text: $viewModel.make,
                icon: "building.2.fill",
                keyboardType: .default,
                field: .make,
                errorMessage: viewModel.make.isEmpty ? "Make is required" : nil
            )
            
            // Model - Editable
            inputField(
                title: "Model",
                placeholder: "Enter vehicle model",
                text: $viewModel.model,
                icon: "car.2.fill",
                keyboardType: .default,
                field: .model,
                errorMessage: viewModel.model.isEmpty ? "Model is required" : nil
            )
            
            // Year - Editable
            VStack(alignment: .leading, spacing: 8) {
                Text("Year")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter vehicle year", value: $viewModel.year, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.year < 1990 ? Color.red : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.year < 1990 {
                    Text("Year must be 1990 or later")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            // VIN - Editable
            inputField(
                title: "VIN",
                placeholder: "Enter vehicle identification number",
                text: $viewModel.vin,
                icon: "barcode.fill",
                keyboardType: .default,
                field: .vin,
                errorMessage: viewModel.vin.isEmpty ? "VIN is required" : nil,
                autocapitalization: .characters
            )
            
            // Color - Still editable
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("e.g., White, Silver", text: $viewModel.color)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($focusField, equals: FormField.color)
                        .onSubmit {
                            advanceToNextField(from: .color)
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.color.isEmpty ? Color.red : focusField == .color ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.color.isEmpty {
                    Text("Color is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            // Fuel Type - Editable
            VStack(alignment: .leading, spacing: 16) {
                Text("Fuel Type")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FuelType.allCases, id: \.self) { fuelType in
                        fuelTypeCard(fuelType)
                    }
                }
            }
            
            // Vehicle Type
            VStack(alignment: .leading, spacing: 16) {
                Text("Vehicle Type")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                vehicleTypeSelector
            }
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Documents & Certifications")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Update the vehicle's documentation information as they expire and renew.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("RC Expiry Date")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: $viewModel.rcExpiryDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
            .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            // Insurance Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Insurance Number")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter insurance policy number", text: $viewModel.insuranceNumber)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusField, equals: FormField.insuranceNumber)
                        .onSubmit {
                            advanceToNextField(from: .insuranceNumber)
                        }
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.insuranceNumber.isEmpty ? Color.red : focusField == .insuranceNumber ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.insuranceNumber.isEmpty {
                    Text("Insurance number is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Insurance Expiry Date")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: $viewModel.insuranceExpiryDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            // Pollution Certificate Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Certificate Number")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter certificate number", text: $viewModel.pollutionCertificateNumber)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusField, equals: FormField.pollutionNumber)
                        .onSubmit {
                            advanceToNextField(from: .pollutionNumber)
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.pollutionCertificateNumber.isEmpty ? Color.red : focusField == .pollutionNumber ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.pollutionCertificateNumber.isEmpty {
                    Text("Certificate number is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Certificate Expiry")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: $viewModel.pollutionCertificateExpiryDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }
    
    private var serviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Service Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Keep service history and odometer readings current for proper maintenance tracking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Service Date")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.lastServiceDate ?? Date() },
                            set: { viewModel.lastServiceDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                    .padding()
            .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Service Due")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.nextServiceDue ?? Date() },
                            set: { viewModel.nextServiceDue = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Odometer Reading (km)")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter current kilometers", value: $viewModel.currentOdometer, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            Toggle("Active Vehicle", isOn: Binding<Bool>(
                get: { viewModel.selectedVehicle?.isActive ?? true },
                set: { newValue in
                    // Will be handled in addVehicle()
                }
            ))
                .padding(.vertical, 8)
        }
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .color:
            currentStep = 2 // Move to next step
            focusField = .insuranceNumber
        case .insuranceNumber:
            focusField = .pollutionNumber
        case .pollutionNumber:
            currentStep = 3 // Move to final step
            focusField = nil
        case .make, .model, .registration, .vin:
            // These are read-only fields
            break
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Basic"
        case 2: return "Documents"
        case 3: return "Service"
        default: return ""
        }
    }
    
    private var isStep1Valid: Bool {
        return !viewModel.color.isEmpty
    }
    
    private var isStep2Valid: Bool {
        return !viewModel.insuranceNumber.isEmpty &&
               !viewModel.pollutionCertificateNumber.isEmpty
    }
    
    private var isFormValid: Bool {
        return isStep1Valid && isStep2Valid && viewModel.registrationNumber.count >= 4
    }
    
    private var vehicleTypeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(VehicleType.allCases, id: \.self) { vehicleType in
                    vehicleTypeCard(vehicleType)
                }
            }
        }
    }
    
    private func vehicleTypeCard(_ type: VehicleType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedVehicleType = type
            }
        } label: {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(viewModel.selectedVehicleType == type ?
                              Color.blue : Color(.systemGray6))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.selectedVehicleType == type ? .white : .primary)
                }
                
                // Type name and description
                VStack(spacing: 4) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: viewModel.selectedVehicleType == type ?
                              Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .stroke(
                        viewModel.selectedVehicleType == type ?
                        Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fuelTypeCard(_ fuelType: FuelType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedFuelType = fuelType
            }
        }) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(viewModel.selectedFuelType == fuelType ?
                              Color.blue : Color(.systemGray6))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: fuelTypeIcon(for: fuelType))
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.selectedFuelType == fuelType ? .white : .primary)
                }
                
                // Type name
                Text(fuelType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: viewModel.selectedFuelType == fuelType ?
                              Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .stroke(
                        viewModel.selectedFuelType == fuelType ?
                        Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fuelTypeIcon(for fuelType: FuelType) -> String {
        switch fuelType {
        case .petrol:
            return "fuelpump.fill"
        case .diesel:
            return "fuelpump"
        case .cng:
            return "seal.fill"
        case .electric:
            return "bolt.fill"
        case .hybrid:
            return "leaf.fill"
        }
    }
}

struct EditVehicleView: View {
    @EnvironmentObject private var viewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @FocusState private var focusField: FormField?
    
    enum FormField {
        case make, model, registration, color, vin, insuranceNumber, pollutionNumber
    }
    
    // Helper function for read-only fields
    private func readOnlyField(
        title: String,
        value: String,
        icon: String
    ) -> some View {
                VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(value)
                    .foregroundColor(.primary)
                }
                .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // Helper function for input fields
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType,
        field: FormField,
        errorMessage: String?,
        autocapitalization: TextInputAutocapitalization = .characters
    ) -> some View {
                VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(autocapitalization)
                    .focused($focusField, equals: field)
                    .onSubmit {
                        advanceToNextField(from: field)
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                            .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(errorMessage != nil ? Color.red : focusField == field ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
            )
            
            if let error = errorMessage {
                Text(error)
                            .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { step in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 24, height: 24)
                            .overlay(
                                    Text("\(step)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(stepTitle(for: step))
                            .font(.caption)
                                .foregroundStyle(step == currentStep ? Color.primary : Color.secondary)
                        }
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                
                // Form content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch currentStep {
                        case 1:
                            basicInfoSection
                                .transition(.opacity)
                        case 2:
                            documentsSection
                                .transition(.opacity)
                        case 3:
                            serviceInfoSection
                                .transition(.opacity)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Bottom navigation
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                .cornerRadius(10)
                        }
                    }
                    
                    if currentStep < 3 {
                        Button(action: {
                            withAnimation {
                                if currentStep == 1 && isStep1Valid {
                                    currentStep += 1
                                } else if currentStep == 2 && isStep2Valid {
                                    currentStep += 1
                                }
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (currentStep == 1 && isStep1Valid) || (currentStep == 2 && isStep2Valid)
                                ? Color.blue
                                : Color.blue.opacity(0.3)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled((currentStep == 1 && !isStep1Valid) || (currentStep == 2 && !isStep2Valid))
                    } else {
                        Button(action: {
                            viewModel.updateVehicle()
                            dismiss()
                        }) {
                            Text("Update Vehicle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.blue : Color.blue.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(!isFormValid)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                                Rectangle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
                )
            }
            .background(Color(.systemGroupedBackground))
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusField = .registration
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Vehicle Details")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Vehicle's core identification fields cannot be modified.")
                        .font(.subheadline)
                .foregroundColor(.secondary)
                
            // Registration Number - Read Only
            readOnlyField(
                title: "Registration Number",
                value: viewModel.registrationNumber,
                icon: "car.fill"
            )
            
            // Make - Read Only
            readOnlyField(
                title: "Make",
                value: viewModel.make,
                icon: "building.2.fill"
            )
            
            // Model - Read Only
            readOnlyField(
                title: "Model",
                value: viewModel.model,
                icon: "car.2.fill"
            )
            
            // Year - Read Only
            readOnlyField(
                title: "Year",
                value: "\(viewModel.year)",
                icon: "calendar"
            )
            
            // VIN - Read Only
            readOnlyField(
                title: "VIN",
                value: viewModel.vin,
                icon: "barcode.fill"
            )
            
            // Color - Still editable
            inputField(
                title: "Color",
                placeholder: "e.g., White, Silver",
                text: $viewModel.color,
                icon: "paintpalette.fill",
                keyboardType: .default,
                field: .color,
                errorMessage: viewModel.color.isEmpty ? "Color is required" : nil
            )
            
            // Fuel Type - Still editable
            VStack(alignment: .leading, spacing: 16) {
                Text("Fuel Type")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FuelType.allCases, id: \.self) { fuelType in
                        fuelTypeCard(fuelType)
                    }
                }
            }
            
            // Vehicle Type - Read Only
                VStack(alignment: .leading, spacing: 8) {
                Text("Vehicle Type")
                    .font(.headline)
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: viewModel.selectedVehicleType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedVehicleType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(viewModel.selectedVehicleType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Documents & Certifications")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Update the vehicle's documentation information as they expire and renew.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("RC Expiry Date")
                    .font(.headline)
                
        HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
            DatePicker(
                        "",
                        selection: $viewModel.rcExpiryDate,
                displayedComponents: .date
            )
            .labelsHidden()
                }
                .padding()
            .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            // Insurance Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Insurance Number")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter insurance policy number", text: $viewModel.insuranceNumber)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusField, equals: FormField.insuranceNumber)
                        .onSubmit {
                            advanceToNextField(from: .insuranceNumber)
                        }
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.insuranceNumber.isEmpty ? Color.red : focusField == .insuranceNumber ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.insuranceNumber.isEmpty {
                    Text("Insurance number is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Insurance Expiry Date")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: $viewModel.insuranceExpiryDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            // Pollution Certificate Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Certificate Number")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter certificate number", text: $viewModel.pollutionCertificateNumber)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($focusField, equals: FormField.pollutionNumber)
                        .onSubmit {
                            advanceToNextField(from: .pollutionNumber)
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.pollutionCertificateNumber.isEmpty ? Color.red : focusField == .pollutionNumber ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
                
                if viewModel.pollutionCertificateNumber.isEmpty {
                    Text("Certificate number is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Certificate Expiry")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: $viewModel.pollutionCertificateExpiryDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
            .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }
    
    private var serviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Service Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Keep service history and odometer readings current for proper maintenance tracking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Service Date")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.lastServiceDate ?? Date() },
                            set: { viewModel.lastServiceDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                    .padding()
            .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Service Due")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.nextServiceDue ?? Date() },
                            set: { viewModel.nextServiceDue = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Odometer Reading (km)")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    TextField("Enter current kilometers", value: $viewModel.currentOdometer, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }
                    .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
            }
            
            Toggle("Active Vehicle", isOn: Binding<Bool>(
                get: { viewModel.selectedVehicle?.isActive ?? true },
                set: { newValue in
                    // Will be handled in updateVehicle()
                }
            ))
                .padding(.vertical, 8)
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Basic"
        case 2: return "Documents"
        case 3: return "Service"
        default: return ""
        }
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .color:
            currentStep = 2 // Move to next step
            focusField = .insuranceNumber
        case .insuranceNumber:
            focusField = .pollutionNumber
        case .pollutionNumber:
            currentStep = 3 // Move to final step
            focusField = nil
        case .make, .model, .registration, .vin:
            // These are read-only fields
            break
        }
    }
    
    private var isStep1Valid: Bool {
        return !viewModel.color.isEmpty
    }
    
    private var isStep2Valid: Bool {
        return !viewModel.insuranceNumber.isEmpty &&
               !viewModel.pollutionCertificateNumber.isEmpty
    }
    
    private var isFormValid: Bool {
        return isStep1Valid && isStep2Valid && viewModel.registrationNumber.count >= 4
    }
    
    private var vehicleTypeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(VehicleType.allCases, id: \.self) { vehicleType in
                    vehicleTypeCard(vehicleType)
                }
            }
        }
    }
    
    private func vehicleTypeCard(_ type: VehicleType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedVehicleType = type
            }
        } label: {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(viewModel.selectedVehicleType == type ?
                              Color.blue : Color(.systemGray6))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.selectedVehicleType == type ? .white : .primary)
                }
                
                // Type name and description
                VStack(spacing: 4) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: viewModel.selectedVehicleType == type ?
                              Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .stroke(
                        viewModel.selectedVehicleType == type ?
                        Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fuelTypeCard(_ fuelType: FuelType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedFuelType = fuelType
            }
        }) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(viewModel.selectedFuelType == fuelType ?
                              Color.blue : Color(.systemGray6))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: fuelTypeIcon(for: fuelType))
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.selectedFuelType == fuelType ? .white : .primary)
                }
                
                // Type name
                Text(fuelType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: viewModel.selectedFuelType == fuelType ?
                              Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadius)
                    .stroke(
                        viewModel.selectedFuelType == fuelType ?
                        Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fuelTypeIcon(for fuelType: FuelType) -> String {
        switch fuelType {
        case .petrol:
            return "fuelpump.fill"
        case .diesel:
            return "fuelpump"
        case .cng:
            return "seal.fill"
        case .electric:
            return "bolt.fill"
        case .hybrid:
            return "leaf.fill"
        }
    }
}

