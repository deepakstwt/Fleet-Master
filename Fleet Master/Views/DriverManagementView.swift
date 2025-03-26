import SwiftUI

struct DriverManagementView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @State private var selectedDriver: Driver?
    @State private var scrollPosition: String?
    @State private var isSearchFocused = false
    @State private var showFilterMenu = false
    @State private var selectedSortOption: SortOption = .nameAsc
    
    // Nested StatusBadge struct for proper namespacing
    struct StatusBadge: View {
        let text: String
        let color: Color
        
        var body: some View {
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.15))
                .cornerRadius(4)
        }
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case newest = "Newest First"
        case oldest = "Oldest First"
        
        var id: Self { self }
    }
    
    var sortedDrivers: [Driver] {
        let filtered = viewModel.filteredDrivers
        
        switch selectedSortOption {
        case .nameAsc:
            return filtered.sorted { $0.name < $1.name }
        case .nameDesc:
            return filtered.sorted { $0.name > $1.name }
        case .newest:
            return filtered.sorted { $0.hireDate > $1.hireDate }
        case .oldest:
            return filtered.sorted { $0.hireDate < $1.hireDate }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Search Bar
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                                .foregroundColor(isSearchFocused || !viewModel.searchText.isEmpty ? .blue : .secondary)
                                .animation(.easeInOut(duration: 0.2), value: isSearchFocused || !viewModel.searchText.isEmpty)
                            
                            TextField("Search by name, email, or license", text: $viewModel.searchText)
                                .disableAutocorrection(true)
                                .onTapGesture {
                                    isSearchFocused = true
                                }
                                .onSubmit {
                                    isSearchFocused = false
                                }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSearchFocused ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                        )
                        
                        // Filter Button
                        Menu {
                            Menu {
                                Picker("Sort", selection: $selectedSortOption) {
                                    ForEach(SortOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                            }
                            
                            Divider()
                            
                            Toggle("Active Drivers Only", isOn: $viewModel.filterActive)
                            
                            Divider()
                            
                            Button("All Drivers") {
                                viewModel.filterActive = false
                            }
                            Button("Available Drivers") {
                                viewModel.filterActive = true
                                viewModel.searchText = ""
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        
                        // Add Driver Button
                    Button(action: {
                        viewModel.isShowingAddDriver = true
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Loading indicator
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading drivers...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if sortedDrivers.isEmpty {
                    EmptyStateView(
                        icon: "person.fill",
                        title: "No Drivers Found",
                        message: viewModel.searchText.isEmpty ? 
                                "Add your first driver using the + button above" :
                                "Try a different search term or filter"
                    )
                } else {
                    // Driver List with improved layout and pull-to-refresh
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedDrivers) { driver in
                                DriverCard(driver: driver)
                                    .scrollTransition { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1.0 : 0.5)
                                            .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                                    }
                                    .id(driver.id)
                            .onTapGesture {
                                selectedDriver = driver
                                    }
                                    .contextMenu {
                                        Button {
                                            viewModel.selectDriverForEdit(driver: driver)
                                        } label: {
                                            Label("Edit Driver", systemImage: "pencil")
                                        }
                                        
                                Button {
                                    viewModel.toggleDriverAvailability(driver: driver)
                                } label: {
                                    Label(driver.isAvailable ? "Set Unavailable" : "Set Available", 
                                          systemImage: driver.isAvailable ? "person.crop.circle.badge.xmark.fill" : "person.crop.circle.badge.checkmark.fill")
                                }
                                
                                        if driver.isActive {
                                            Button(role: .destructive) {
                                    viewModel.toggleDriverStatus(driver: driver)
                                } label: {
                                                Label("Disable Driver", systemImage: "person.crop.circle.badge.xmark")
                                }
                                        } else {
                                Button {
                                                viewModel.toggleDriverStatus(driver: driver)
                                } label: {
                                                Label("Enable Driver", systemImage: "person.crop.circle.badge.checkmark")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable {
                        await refreshDrivers()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrollPosition)
                }
                
                // Error message banner if there's an issue
                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .onTapGesture {
                                viewModel.errorMessage = nil
                            }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Driver Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .refreshable {
                await refreshDrivers()
            }
            .sheet(isPresented: $viewModel.isShowingAddDriver) {
                AddDriverView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditDriver) {
                EditDriverView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $selectedDriver) { driver in
                    DriverDetailView(driver: driver)
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    // Helper function to refresh drivers asynchronously
    func refreshDrivers() async {
        // Create a Task that calls the view model's fetchDrivers method
        // We need to wrap this in a Task since fetchDrivers() isn't async itself
        // but internally uses Task for async operations
        await withCheckedContinuation { continuation in
            viewModel.fetchDrivers()
            // Continue after a short delay to ensure the refresh indicator shows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}

struct DriverCard: View {
    let driver: Driver
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(statusColor)
            }
            
            // Driver Info
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(driver.isActive ? .primary : .secondary)
                
                Text(driver.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Text("License: \(driver.licenseNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                    DriverManagementView.StatusBadge(text: statusText, color: statusColor)
                }
                .padding(.top, 2)
                
                // Vehicle Categories
                if !driver.vehicleCategories.isEmpty {
                HStack(spacing: 6) {
                        ForEach(driver.vehicleCategories, id: \.self) { category in
                            VehicleCategoryBadge(category: category)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var statusText: String {
        if !driver.isActive {
            return "Inactive"
        } else if driver.isAvailable {
            return "Available"
                    } else {
            return "Unavailable"
        }
    }
    
    private var statusColor: Color {
        if !driver.isActive {
            return .red
        } else if driver.isAvailable {
            return .green
        } else {
            return .orange
        }
    }
}

struct VehicleCategoryBadge: View {
    let category: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: vehicleCategoryIcon(for: category))
                .font(.system(size: 8))
            
            Text(category)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
    
    private func vehicleCategoryIcon(for category: String) -> String {
        switch category {
        case "LMV-TR": return "car.fill"
        case "MGV": return "truck.pickup.side.fill"
        case "HMV", "HTV": return "bus.fill"
        case "HPMV": return "bus.doubledecker.fill"
        case "HGMV": return "truck.box.fill"
        case "PSV": return "person.3.fill"
        case "TRANS": return "arrow.triangle.swap"
        default: return "car.fill"
        }
    }
}

struct AddDriverView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFormValid = false
    @State private var selectedCategories: Set<String> = []
    @State private var currentStep = 1
    @State private var showingHelp = false
    @FocusState private var focusField: FormField?
    
    enum FormField {
        case name, email, phone, license
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
                            personalInfoSection
                                .transition(.opacity)
                        case 2:
                            licenseInfoSection
                                .transition(.opacity)
                        case 3:
                            vehicleCategoriesSection
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
                            viewModel.vehicleCategories = Array(selectedCategories)
                        viewModel.addDriver()
                        dismiss()
                        }) {
                            Text("Add Driver")
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
            .navigationTitle("Add New Driver")
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
                    Text("Adding a New Driver")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        helpItem(icon: "1.circle.fill", title: "Personal Information", 
                                description: "Enter the driver's full name, email address, and phone number.")
                        
                        helpItem(icon: "2.circle.fill", title: "License Information", 
                                description: "Enter the driver's license number according to their RTO-issued driving license.")
                        
                        helpItem(icon: "3.circle.fill", title: "Vehicle Categories", 
                                description: "Select all the vehicle categories the driver is licensed to operate based on their driving license endorsements.")
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
                    focusField = .name
                }
            }
        }
    }
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personal Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Enter the driver's personal details for identification and communication.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            inputField(
                title: "Full Name",
                placeholder: "Enter driver's full name",
                text: $viewModel.name,
                icon: "person.fill",
                keyboardType: .default,
                field: .name,
                errorMessage: viewModel.name.isEmpty ? "Name is required" : nil
            )
            
            inputField(
                title: "Email Address",
                placeholder: "Enter email address",
                text: $viewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                field: .email,
                errorMessage: !isEmailValid ? "Enter a valid email address" : nil
            )
            
            inputField(
                title: "Phone Number",
                placeholder: "Enter 10-digit phone number",
                text: $viewModel.phone,
                icon: "phone.fill",
                keyboardType: .phonePad,
                field: .phone,
                errorMessage: !isPhoneValid ? "Enter a valid 10-digit phone number" : nil
            )
        }
    }
    
    private var licenseInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("License Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Enter the driver's license details as they appear on their RTO-issued driving license.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            inputField(
                title: "License Number",
                placeholder: "e.g., DL-0420110012345",
                text: $viewModel.licenseNumber,
                icon: "creditcard.fill",
                keyboardType: .default,
                field: .license,
                errorMessage: viewModel.licenseNumber.isEmpty ? "License number is required" : nil
            )
            
            Toggle("Available for Trips", isOn: $viewModel.isAvailable)
                .padding(.vertical, 8)
        }
    }
    
    private var vehicleCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Vehicle Categories")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Select all vehicle categories this driver is licensed to operate based on their driving license endorsements.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                ForEach(Array(Driver.licenseCategories.keys).sorted(), id: \.self) { category in
                    categorySelectionButton(category)
                }
            }
            
            if selectedCategories.isEmpty {
                Text("Please select at least one vehicle category")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
    
    private func categorySelectionButton(_ category: String) -> some View {
        Button {
            toggleCategory(category)
        } label: {
            HStack(spacing: 16) {
                // Category icon
                Image(systemName: vehicleCategoryIcon(for: category))
                    .font(.system(size: 20))
                    .foregroundColor(selectedCategories.contains(category) ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        selectedCategories.contains(category) 
                        ? Color.blue 
                        : Color(.systemGray5)
                    )
                    .clipShape(Circle())
                
                // Category text
                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(Driver.licenseCategories[category] ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedCategories.contains(category) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                } else {
                    Circle()
                        .strokeBorder(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType,
        field: FormField,
        errorMessage: String?
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
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
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
    
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        
        validateForm()
    }
    
    private func validateForm() {
        isFormValid = isStep1Valid && isStep2Valid && !selectedCategories.isEmpty
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .name:
            focusField = .email
        case .email:
            focusField = .phone
        case .phone:
            focusField = .license
        case .license:
            focusField = nil
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Personal"
        case 2: return "License"
        case 3: return "Categories"
        default: return ""
        }
    }
    
    private var isEmailValid: Bool {
        if viewModel.email.isEmpty { return true }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return viewModel.email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private var isPhoneValid: Bool {
        if viewModel.phone.isEmpty { return true }
        let phoneRegex = #"^\d{10}$"#
        return viewModel.phone.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    private var isStep1Valid: Bool {
        return !viewModel.name.isEmpty && isEmailValid && isPhoneValid && !viewModel.email.isEmpty && !viewModel.phone.isEmpty
    }
    
    private var isStep2Valid: Bool {
        return !viewModel.licenseNumber.isEmpty
    }
    
    private func vehicleCategoryIcon(for category: String) -> String {
        switch category {
        case "LMV-TR": return "car.fill"
        case "MGV": return "truck.pickup.side.fill"
        case "HMV", "HTV": return "bus.fill"
        case "HPMV": return "bus.doubledecker.fill"
        case "HGMV": return "truck.box.fill"
        case "PSV": return "person.3.fill"
        case "TRANS": return "arrow.triangle.swap"
        default: return "car.fill"
        }
    }
}

struct EditDriverView: View {
    @EnvironmentObject private var viewModel: DriverViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFormValid = false
    @State private var selectedCategories: Set<String> = []
    @State private var currentStep = 1
    @FocusState private var focusField: FormField?
    
    enum FormField {
        case name, email, phone, license
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
                            personalInfoSection
                                .transition(.opacity)
                        case 2:
                            licenseInfoSection
                                .transition(.opacity)
                        case 3:
                            vehicleCategoriesSection
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
                            viewModel.vehicleCategories = Array(selectedCategories)
                        viewModel.updateDriver()
                        dismiss()
                        }) {
                            Text("Update Driver")
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
            .navigationTitle("Edit Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedCategories = Set(viewModel.vehicleCategories)
                validateForm()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusField = .name
                }
            }
        }
    }
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personal Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Update the driver's personal details for identification and communication.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            inputField(
                title: "Full Name",
                placeholder: "Enter driver's full name",
                text: $viewModel.name,
                icon: "person.fill",
                keyboardType: .default,
                field: .name,
                errorMessage: viewModel.name.isEmpty ? "Name is required" : nil
            )
            
            inputField(
                title: "Email Address",
                placeholder: "Enter email address",
                text: $viewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                field: .email,
                errorMessage: !isEmailValid ? "Enter a valid email address" : nil
            )
            
            inputField(
                title: "Phone Number",
                placeholder: "Enter 10-digit phone number",
                text: $viewModel.phone,
                icon: "phone.fill",
                keyboardType: .phonePad,
                field: .phone,
                errorMessage: !isPhoneValid ? "Enter a valid 10-digit phone number" : nil
            )
        }
    }
    
    private var licenseInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("License Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("License number cannot be modified. Update the driver's availability status as needed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // License Number - Read Only
            readOnlyField(
                title: "License Number",
                value: viewModel.licenseNumber,
                icon: "creditcard.fill"
            )
            
            Toggle("Available for Trips", isOn: $viewModel.isAvailable)
                .padding(.vertical, 8)
        }
    }
    
    private var vehicleCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Vehicle Categories")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Select all vehicle categories this driver is licensed to operate based on their driving license endorsements.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                ForEach(Array(Driver.licenseCategories.keys).sorted(), id: \.self) { category in
                    categorySelectionButton(category)
                }
            }
            
            if selectedCategories.isEmpty {
                Text("Please select at least one vehicle category")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
    
    private func categorySelectionButton(_ category: String) -> some View {
        Button {
            toggleCategory(category)
        } label: {
            HStack(spacing: 16) {
                // Category icon
                Image(systemName: vehicleCategoryIcon(for: category))
                    .font(.system(size: 20))
                    .foregroundColor(selectedCategories.contains(category) ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        selectedCategories.contains(category) 
                        ? Color.blue 
                        : Color(.systemGray5)
                    )
                    .clipShape(Circle())
                
                // Category text
                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(Driver.licenseCategories[category] ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedCategories.contains(category) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                } else {
                    Circle()
                        .strokeBorder(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType,
        field: FormField,
        errorMessage: String?
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
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
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
    
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        
        validateForm()
    }
    
    private func validateForm() {
        isFormValid = isStep1Valid && isStep2Valid && !selectedCategories.isEmpty
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .name:
            focusField = .email
        case .email:
            focusField = .phone
        case .phone:
            focusField = .license
        case .license:
            focusField = nil
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Personal"
        case 2: return "License"
        case 3: return "Categories"
        default: return ""
        }
    }
    
    private var isEmailValid: Bool {
        if viewModel.email.isEmpty { return true }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return viewModel.email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private var isPhoneValid: Bool {
        if viewModel.phone.isEmpty { return true }
        let phoneRegex = #"^\d{10}$"#
        return viewModel.phone.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    private var isStep1Valid: Bool {
        return !viewModel.name.isEmpty && isEmailValid && isPhoneValid && !viewModel.email.isEmpty && !viewModel.phone.isEmpty
    }
    
    private var isStep2Valid: Bool {
        return !viewModel.licenseNumber.isEmpty
    }
    
    private func vehicleCategoryIcon(for category: String) -> String {
        switch category {
        case "LMV-TR": return "car.fill"
        case "MGV": return "truck.pickup.side.fill"
        case "HMV", "HTV": return "bus.fill"
        case "HPMV": return "bus.doubledecker.fill"
        case "HGMV": return "truck.box.fill"
        case "PSV": return "person.3.fill"
        case "TRANS": return "arrow.triangle.swap"
        default: return "car.fill"
        }
    }
}

struct DriverDetailView: View {
    let driver: Driver
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(statusColor)
                        }
                        
                        Text(driver.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DriverManagementView.StatusBadge(
                            text: statusText,
                            color: statusColor
                        )
                        
                        // Vehicle Categories
                        if !driver.vehicleCategories.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(driver.vehicleCategories, id: \.self) { category in
                                    VehicleCategoryBadge(category: category)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Driver Info Sections
                    VStack(spacing: 20) {
                        DetailSection(title: "Personal Information", items: [
                            DetailItem(icon: "envelope.fill", title: "Email", value: driver.email),
                            DetailItem(icon: "phone.fill", title: "Phone", value: driver.phone)
                        ])
                        
                        DetailSection(title: "Driver Information", items: [
                            DetailItem(icon: "person.text.rectangle.fill", title: "ID", value: driver.id),
                            DetailItem(icon: "creditcard.fill", title: "License Number", value: driver.licenseNumber),
                            DetailItem(icon: "calendar", title: "Hire Date", value: formatDate(driver.hireDate))
                        ])
                        
                        if !driver.vehicleCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Licensed Vehicle Categories")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 12) {
                                    ForEach(driver.vehicleCategories.chunked(into: 2), id: \.self) { row in
                                        HStack {
                                            ForEach(row, id: \.self) { category in
                                                HStack {
                                                    Image(systemName: vehicleCategoryIcon(for: category))
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.primary)
                                                        .frame(width: 32, height: 32)
                                                        .background(Color(.systemGray5))
                                                        .clipShape(Circle())
                                                    
                                                    VStack(alignment: .leading) {
                                                        Text(category)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                        
                                                        Text(vehicleCategoryDescription(for: category))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color(.systemBackground))
                                                .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
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
    
    private var statusText: String {
        if !driver.isActive {
            return "Inactive"
        } else if driver.isAvailable {
            return "Available"
        } else {
            return "Unavailable"
        }
    }
    
    private var statusColor: Color {
        if !driver.isActive {
            return .red
        } else if driver.isAvailable {
            return .green
        } else {
            return .orange
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func vehicleCategoryIcon(for category: String) -> String {
        switch category {
        case "LMV-TR": return "car.fill"
        case "MGV": return "truck.pickup.side.fill"
        case "HMV", "HTV": return "bus.fill"
        case "HPMV": return "bus.doubledecker.fill"
        case "HGMV": return "truck.box.fill"
        case "PSV": return "person.3.fill"
        case "TRANS": return "arrow.triangle.swap"
        default: return "car.fill"
        }
    }
    
    private func vehicleCategoryDescription(for category: String) -> String {
        return Driver.licenseCategories[category] ?? ""
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct DetailSection: View {
    let title: String
    let items: [DetailItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(items) { item in
                    HStack(spacing: 16) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption)
                .foregroundColor(.secondary)
                            
                            Text(item.value)
                                .font(.body)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
            }
        }
    }
}

struct DetailItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
}

#Preview {
    DriverManagementView()
        .environmentObject(DriverViewModel())
} 
