import SwiftUI

// This file contains the Maintenance Management view
struct MaintenanceManagementView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @State private var selectedPersonnel: MaintenancePersonnel?
    @State private var scrollPosition: String?
    @State private var isSearchFocused = false
    @State private var showFilterMenu = false
    @State private var selectedSortOption: SortOption = .nameAsc
    @State private var filterActive = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case newest = "Newest First"
        case oldest = "Oldest First"
        
        var id: Self { self }
    }
    
    var sortedPersonnel: [MaintenancePersonnel] {
        let filtered = viewModel.filteredPersonnel.filter { personnel in
            return !filterActive || personnel.isActive
        }
        
        switch selectedSortOption {
        case .nameAsc:
            return filtered.sorted { $0.name < $1.name }
        case .nameDesc:
            return filtered.sorted { $0.name > $1.name }
        case .newest:
            return filtered.sorted { $0.id > $1.id } // Assuming ID can be used as proxy for creation date
        case .oldest:
            return filtered.sorted { $0.id < $1.id }
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
                            
                            TextField("Search maintenance personnel...", text: $viewModel.searchText)
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
                            
                            Toggle("Active Personnel Only", isOn: $filterActive)
                            
                            Divider()
                            
                            Button("All Personnel") {
                                filterActive = false
                            }
                            Button("Active Personnel") {
                                filterActive = true
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
                        
                        // Add Personnel Button
                        Button(action: {
                            viewModel.isShowingAddPersonnel = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                // Loading indicator
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading personnel...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if sortedPersonnel.isEmpty {
                    EmptyStateView(
                        icon: "wrench.fill",
                        title: "No Personnel Found",
                        message: viewModel.searchText.isEmpty ? 
                                "Add your first maintenance personnel using the + button above" :
                                "Try a different search term or filter"
                    )
                } else {
                    // Personnel List with improved layout and pull-to-refresh
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedPersonnel) { person in
                                MaintenanceCard(person: person)
                                    .scrollTransition { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1.0 : 0.5)
                                            .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                                    }
                                    .id(person.id)
                                    .onTapGesture {
                                        selectedPersonnel = person
                                    }
                                    .contextMenu {
                                        Button {
                                            viewModel.selectPersonnelForEdit(person: person)
                                        } label: {
                                            Label("Edit Personnel", systemImage: "pencil")
                                        }
                                        
                                        if person.isActive {
                                            Button(role: .destructive) {
                                                viewModel.togglePersonnelStatus(person: person)
                                            } label: {
                                                Label("Disable Personnel", systemImage: "person.crop.circle.badge.xmark")
                                            }
                                        } else {
                                            Button {
                                                viewModel.togglePersonnelStatus(person: person)
                                            } label: {
                                                Label("Enable Personnel", systemImage: "person.crop.circle.badge.checkmark")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable {
                        Task {
                            await refreshPersonnel()
                        }
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrollPosition)
                }
                
                // Error message banner if there's an issue
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(8)
                        
                        if errorMessage.contains("format") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Possible solutions:")
                                    .font(.headline)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• Run the SQL setup script to create the table properly")
                                    Text("• Check that JSON field names match Swift model properties")
                                    Text("• Verify date formatting between Swift and Supabase")
                                }
                                .font(.subheadline)
                                
                                Button(action: {
                                    viewModel.testSupabaseSetup()
                                }) {
                                    Text("Run Database Test")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Maintenance Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(isPresented: $viewModel.isShowingAddPersonnel) {
                AddMaintenanceView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditPersonnel) {
                EditMaintenanceView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $selectedPersonnel) { person in
                MaintenanceDetailView(person: person)
            }
        }
    }
    
    // Helper function to refresh personnel asynchronously
    func refreshPersonnel() async {
        // Create a Task that calls the view model's fetchPersonnel method
        // We need to wrap this in a Task since fetchPersonnel() isn't async itself
        // but internally uses Task for async operations
        await withCheckedContinuation { continuation in
            viewModel.fetchPersonnel()
            // Continue after a short delay to ensure the refresh indicator shows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
}

struct MaintenanceCard: View {
    let person: MaintenancePersonnel
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "wrench.fill")
                    .font(.system(size: 24))
                    .foregroundColor(statusColor)
            }
            
            // Personnel Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                Text(person.name)
                        .font(.headline)
                    
                    if !person.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                
                Text(person.email)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(person.phone)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "medal.star.fill")
                        .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("\(person.certifications.count) certs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(person.skills.count) skills")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        return person.isActive ? Color.green : Color.red
    }
}

struct SkillBadge: View {
    let skill: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: skillIcon(for: skill))
                .font(.system(size: 8))
            
            Text(skill)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
    
    private func skillIcon(for skill: String) -> String {
        switch skill.lowercased() {
        case _ where skill.contains("engine"): return "engine.combustion.fill"
        case _ where skill.contains("electric"): return "bolt.fill"
        case _ where skill.contains("brake"): return "car.windshield.rear"
        case _ where skill.contains("body"): return "car.side.fill"
        case _ where skill.contains("transmission"): return "gearshape.2.fill"
        default: return "wrench.and.screwdriver.fill"
        }
    }
}

struct AddMaintenanceView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFormValid = false
    @State private var currentStep = 1
    @State private var showingHelp = false
    @FocusState private var focusField: FormField?
    @State private var selectedCategory: Certification.CertificationCategory = .technician
    @State private var selectedCertificationsToAdd: Set<String> = [] // Track selected certifications by ID
    
    enum FormField {
        case name, email, phone
    }
    
    // MARK: - Certification & Skill Views
    
    // Updated certification selection view with multi-select support
    private var selectCertificationView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Certification.CertificationCategory.allCases, id: \.self) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? 
                                                  Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .foregroundColor(selectedCategory == category ? .blue : .primary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Certification list with multi-select support
                List {
                    let filteredCertifications = viewModel.certifications(for: selectedCategory)
                    
                    Section(header: Text("Available Certifications")) {
                        if filteredCertifications.isEmpty {
                            Text("No certifications available in this category")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredCertifications) { cert in
                                if !viewModel.selectedCertifications.contains(where: { $0.id == cert.id }) {
                                    Button(action: {
                                        // Toggle selection
                                        if selectedCertificationsToAdd.contains(cert.id) {
                                            selectedCertificationsToAdd.remove(cert.id)
                                        } else {
                                            selectedCertificationsToAdd.insert(cert.id)
                                        }
                                    }) {
                HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(cert.name)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                
                                                Text(cert.issuer)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Selection indicator
                                            Image(systemName: selectedCertificationsToAdd.contains(cert.id) ? 
                                                  "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedCertificationsToAdd.contains(cert.id) ? 
                                                              .blue : .secondary)
                                                .imageScale(.large)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    
                    // Already selected certifications section
                    if !viewModel.selectedCertifications.isEmpty {
                        Section(header: Text("Already Selected")) {
                            ForEach(viewModel.selectedCertifications.filter { $0.category == selectedCategory }) { cert in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cert.name)
                                            .font(.body)
                                        
                                        Text(cert.issuer)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                .contentShape(Rectangle())
                                .opacity(0.6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Certifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedCertificationsToAdd.removeAll()
                        viewModel.isAddingCertification = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedCertificationsToAdd.count)") {
                        // Get the certification objects from their IDs
                        let certificationsToAdd = viewModel.predefinedCertifications.filter { 
                            selectedCertificationsToAdd.contains($0.id) 
                        }
                        viewModel.addMultipleCertifications(certificationsToAdd)
                        selectedCertificationsToAdd.removeAll()
                    }
                    .disabled(selectedCertificationsToAdd.isEmpty)
                    .font(.headline)
                }
            }
        }
    }
    
    private var addSkillView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Form {
                    Section {
                        TextField("Skill Name", text: $viewModel.skillName)
                            .autocorrectionDisabled()
                        
                        Picker("Proficiency Level", selection: $viewModel.skillProficiency) {
                            ForEach(Skill.ProficiencyLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        
                        Picker("Experience Years", selection: $viewModel.skillYears) {
                            ForEach(0...30, id: \.self) { year in
                                Text("\(year) \(year == 1 ? "year" : "years")").tag(year)
                            }
                        }
                    } header: {
                        Text("Skill Details")
                    } footer: {
                        Text("Add details about the skills and expertise of the maintenance personnel.")
                    }
                }
                
                Button("Add Skill") {
                    viewModel.addSkill()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.skillName.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isAddingSkill = false
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator with improved styling
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { step in
                        VStack(spacing: 6) {
                        Circle()
                                .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Text("\(step)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(stepTitle(for: step))
                                .font(.caption)
                                .fontWeight(step == currentStep ? .medium : .regular)
                                .foregroundStyle(step == currentStep ? Color.primary : Color.secondary)
                        }
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(Color(.systemBackground))
                
                // Form content based on current step
                ScrollView {
                    VStack(spacing: 0) {
                        if currentStep == 1 {
                            personalInfoSection
                                .transition(.opacity)
                        } else if currentStep == 2 {
                            certificationsSection
                                .transition(.opacity)
                        } else {
                            skillsSection
                                .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 600)
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(Color(.systemGroupedBackground))
                
                // Navigation buttons with improved styling
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.caption.bold())
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                    
                    if currentStep < 3 {
                        Button(action: {
                            withAnimation {
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(currentStep == 1 && !isStep1Valid)
                        .opacity(currentStep == 1 && !isStep1Valid ? 0.6 : 1)
                    } else {
                        Button("Add Personnel") {
                            viewModel.addPersonnel()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isFormValid ? Color.blue : Color.blue.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Maintenance Personnel")
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
            .sheet(isPresented: $viewModel.isAddingCertification) {
                selectCertificationView
            }
            .sheet(isPresented: $viewModel.isAddingSkill) {
                addSkillView
            }
            .sheet(isPresented: $showingHelp) {
                helpView
            }
            .onAppear {
                validateForm()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusField = .name
                }
            }
            .onChange(of: viewModel.name) { validateForm() }
            .onChange(of: viewModel.email) { validateForm() }
            .onChange(of: viewModel.phone) { validateForm() }
            .onChange(of: viewModel.selectedCertifications.count) { validateForm() }
            .onChange(of: viewModel.selectedSkills.count) { validateForm() }
        }
    }
    
    // MARK: - Form Sections
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personal Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Enter the maintenance personnel's personal details for identification and communication.")
                .font(.subheadline)
                    .foregroundColor(.secondary)
            
            inputField(
                title: "Full Name",
                placeholder: "Enter full name",
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
    
    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
                Text("Certifications")
                .font(.title3)
                .fontWeight(.bold)
                
            Text("Select relevant certifications from the predefined list. You can select multiple certifications at once.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                
            HStack {
                Spacer()
                Button(action: {
                    viewModel.isAddingCertification = true
                }) {
                    Label("Select Certifications", systemImage: "plus.circle")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            
            if viewModel.selectedCertifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "certificate")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No certifications selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Select certifications by clicking the button above")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.selectedCertifications) { certification in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "medal.star.fill")
                                    .foregroundColor(categoryColor(for: certification.category))
                                
                                Text(certification.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button {
                                    if let index = viewModel.selectedCertifications.firstIndex(where: { $0.id == certification.id }) {
                                viewModel.removeCertification(at: IndexSet(integer: index))
                                    }
                            } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Issuer")
                                        .font(.caption)
                    .foregroundColor(.secondary)
                                    Text(certification.issuer)
                    .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Category")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(certification.category.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(categoryColor(for: certification.category).opacity(0.2))
                                        .foregroundColor(categoryColor(for: certification.category))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
                Text("Skills & Expertise")
                .font(.title3)
                .fontWeight(.bold)
                
            Text("Add relevant skills and expertise areas that the technician possesses.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                
            HStack {
                Spacer()
                Button(action: {
                    viewModel.isAddingSkill = true
                }) {
                    Label("Add Custom Skill", systemImage: "plus.circle")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            
            if viewModel.selectedSkills.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No skills added")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add skills by selecting from common skills below or adding custom skills")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Selected Skills")
                        .font(.headline)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.selectedSkills) { skill in
                            SkillChip(skill: skill) {
                                if let index = viewModel.selectedSkills.firstIndex(where: { $0.id == skill.id }) {
                                    viewModel.removeSkill(at: IndexSet(integer: index))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            Divider()
                .padding(.vertical, 10)
            
            VStack(alignment: .leading, spacing: 16) {
            Text("Common Skills")
                    .font(.headline)
            
                FlowLayout(spacing: 10) {
                ForEach(viewModel.predefinedSkills) { skill in
                    if !viewModel.selectedSkills.contains(where: { $0.name == skill.name }) {
                        Button(action: {
                            viewModel.addPredefinedSkill(skill)
                        }) {
                                HStack(spacing: 6) {
                            Text(skill.name)
                                        .font(.subheadline)
                                    
                                    Image(systemName: "plus")
                                .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(20)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Components
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType, field: FormField, errorMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 0) {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusField, equals: field)
                        .submitLabel(getSubmitLabel(for: field))
                        .onSubmit {
                            advanceToNextField(from: field)
                        }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Views
    
    private var helpView: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Personnel Onboarding")
                            .font(.headline)
                        
                        Text("This form allows you to add new maintenance personnel to the system. Complete all required fields and add relevant certifications and skills.")
                    .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
                            .font(.headline)
                        
                        Text("The first step collects basic contact information. All fields are required for proper identification and communication.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Certifications")
                            .font(.headline)
                        
                        Text("Select from the predefined list of certifications. You can select multiple certifications at once by checking them and clicking 'Add'.")
                            .font(.subheadline)
            }
            .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skills & Expertise")
                            .font(.headline)
                        
                        Text("Select from common skills or add custom skills to indicate the personnel's expertise areas. This information is used when assigning maintenance tasks.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Notes") {
                    Text("• A random 6-digit password will be generated automatically for the new personnel.")
                    Text("• The personnel's ID will be created automatically.")
                    Text("• New personnel are set to 'Active' by default.")
                }
            }
            .navigationTitle("Help & Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingHelp = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateForm() {
        // Step 1 validation handled separately with isStep1Valid
        
        // Final form validation (all steps)
        isFormValid = isStep1Valid
    }
    
    private func getSubmitLabel(for field: FormField) -> SubmitLabel {
        switch field {
        case .name, .email, .phone:
            return .next
        }
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .name:
            focusField = .email
        case .email:
            focusField = .phone
        case .phone:
            focusField = nil
            if isStep1Valid {
                withAnimation {
                    currentStep = 2
                }
            }
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Personal"
        case 2: return "Certifications"
        case 3: return "Skills"
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
    
    private func categoryColor(for category: Certification.CertificationCategory) -> Color {
        switch category {
        case .technician:
            return .blue
        case .manager:
            return .purple
        case .other:
            return .green
        }
    }
}

struct SkillChip: View {
    let skill: Skill
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(skill.name)
                .font(.subheadline)
            
            Text(skill.proficiencyLevel.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(proficiencyColor.opacity(0.2))
                .foregroundColor(proficiencyColor)
                .cornerRadius(4)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }
    
    private var proficiencyColor: Color {
        switch skill.proficiencyLevel {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .purple
        case .expert:
            return .red
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        
        var heights: [CGFloat] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentRowIndex = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(proposal)
            
            if currentRowWidth + viewSize.width > width {
                // Move to next row
                heights.append(currentRowHeight)
                currentRowWidth = viewSize.width + spacing
                currentRowHeight = viewSize.height
                currentRowIndex += 1
            } else {
                // Stay in current row
                currentRowWidth += viewSize.width + spacing
                currentRowHeight = max(currentRowHeight, viewSize.height)
            }
        }
        
        if currentRowHeight > 0 {
            heights.append(currentRowHeight)
        }
        
        return CGSize(
            width: width,
            height: heights.reduce(0) { $0 + $1 } + CGFloat(max(0, heights.count - 1)) * spacing
        )
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        
        _ = bounds.width
        
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(proposal)
            
            if x + viewSize.width > bounds.maxX {
                // Move to next row
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(viewSize))
            
            x += viewSize.width + spacing
            maxHeight = max(maxHeight, viewSize.height)
        }
    }
}

struct EditMaintenanceView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isFormValid = false
    @State private var currentStep = 1
    @FocusState private var focusField: FormField?
    @State private var selectedCategory: Certification.CertificationCategory = .technician
    @State private var selectedCertificationsToAdd: Set<String> = [] // Track selected certifications by ID
    
    enum FormField {
        case name, email, phone
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
    
    // MARK: - Certification & Skill Views
    
    // Updated certification selection view with multi-select support
    private var selectCertificationView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Certification.CertificationCategory.allCases, id: \.self) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? 
                                                  Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .foregroundColor(selectedCategory == category ? .blue : .primary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Certification list with multi-select support
                List {
                    let filteredCertifications = viewModel.certifications(for: selectedCategory)
                    
                    Section(header: Text("Available Certifications")) {
                        if filteredCertifications.isEmpty {
                            Text("No certifications available in this category")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredCertifications) { cert in
                                if !viewModel.selectedCertifications.contains(where: { $0.id == cert.id }) {
                                    Button(action: {
                                        // Toggle selection
                                        if selectedCertificationsToAdd.contains(cert.id) {
                                            selectedCertificationsToAdd.remove(cert.id)
                                        } else {
                                            selectedCertificationsToAdd.insert(cert.id)
                                        }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(cert.name)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                
                                                Text(cert.issuer)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Selection indicator
                                            Image(systemName: selectedCertificationsToAdd.contains(cert.id) ? 
                                                  "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedCertificationsToAdd.contains(cert.id) ? 
                                                              .blue : .secondary)
                                                .imageScale(.large)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    
                    // Already selected certifications section
                    if !viewModel.selectedCertifications.isEmpty {
                        Section(header: Text("Already Selected")) {
                            ForEach(viewModel.selectedCertifications.filter { $0.category == selectedCategory }) { cert in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cert.name)
                                            .font(.body)
                                        
                                        Text(cert.issuer)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                .contentShape(Rectangle())
                                .opacity(0.6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Certifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedCertificationsToAdd.removeAll()
                        viewModel.isAddingCertification = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedCertificationsToAdd.count)") {
                        // Get the certification objects from their IDs
                        let certificationsToAdd = viewModel.predefinedCertifications.filter { 
                            selectedCertificationsToAdd.contains($0.id) 
                        }
                        viewModel.addMultipleCertifications(certificationsToAdd)
                        selectedCertificationsToAdd.removeAll()
                    }
                    .disabled(selectedCertificationsToAdd.isEmpty)
                    .font(.headline)
                }
            }
        }
    }
    
    private var addSkillView: some View {
        NavigationStack {
            VStack(spacing: 20) {
            Form {
                    Section {
                        TextField("Skill Name", text: $viewModel.skillName)
                            .autocorrectionDisabled()
                    
                        Picker("Proficiency Level", selection: $viewModel.skillProficiency) {
                        ForEach(Skill.ProficiencyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                            }
                        }
                        
                        Picker("Experience Years", selection: $viewModel.skillYears) {
                            ForEach(0...30, id: \.self) { year in
                                Text("\(year) \(year == 1 ? "year" : "years")").tag(year)
                            }
                        }
                    } header: {
                        Text("Skill Details")
                    } footer: {
                        Text("Add details about the skills and expertise of the maintenance personnel.")
                    }
                }
                
                Button("Add Skill") {
                    viewModel.addSkill()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(viewModel.skillName.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isAddingSkill = false
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator with improved styling
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { step in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Text("\(step)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(stepTitle(for: step))
                                .font(.caption)
                                .fontWeight(step == currentStep ? .medium : .regular)
                                .foregroundStyle(step == currentStep ? Color.primary : Color.secondary)
                        }
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(Color(.systemBackground))
                
                // Form content based on current step
                ScrollView {
                    VStack(spacing: 0) {
                        if currentStep == 1 {
                            personalInfoSection
                                .transition(.opacity)
                        } else if currentStep == 2 {
                            certificationsSection
                                .transition(.opacity)
                        } else {
                            skillsSection
                                .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 600)
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(Color(.systemGroupedBackground))
                
                // Navigation buttons with improved styling
                HStack(spacing: 16) {
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.caption.bold())
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                    
                    if currentStep < 3 {
                        Button(action: {
                            withAnimation {
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(currentStep == 1 && !isStep1Valid)
                        .opacity(currentStep == 1 && !isStep1Valid ? 0.6 : 1)
                    } else {
                    Button("Update Personnel") {
                        viewModel.updatePersonnel()
                        dismiss()
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isFormValid ? Color.blue : Color.blue.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Maintenance Personnel")
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
            .sheet(isPresented: $viewModel.isAddingCertification) {
                selectCertificationView
            }
            .sheet(isPresented: $viewModel.isAddingSkill) {
                addSkillView
            }
            .onAppear {
                validateForm()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusField = .name
                }
            }
            .onChange(of: viewModel.name) { validateForm() }
            .onChange(of: viewModel.email) { validateForm() }
            .onChange(of: viewModel.phone) { validateForm() }
            .onChange(of: viewModel.selectedCertifications.count) { validateForm() }
            .onChange(of: viewModel.selectedSkills.count) { validateForm() }
        }
    }
    
    // MARK: - Form Sections
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personal Information")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Identification number and system credentials cannot be modified. You can update contact information.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Personnel ID - Read Only
            readOnlyField(
                title: "Personnel ID",
                value: viewModel.selectedPersonnel?.id ?? "",
                icon: "person.text.rectangle.fill"
            )
            
            // Password - Read Only
            readOnlyField(
                title: "System Password",
                value: viewModel.selectedPersonnel?.password ?? "******",
                icon: "lock.fill"
            )
            
            inputField(
                title: "Full Name",
                placeholder: "Enter full name",
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
    
    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Certifications")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Select relevant certifications from the predefined list. You can select multiple certifications at once.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button(action: {
                    viewModel.isAddingCertification = true
                }) {
                    Label("Select Certifications", systemImage: "plus.circle")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            
            if viewModel.selectedCertifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "certificate")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No certifications selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Select certifications by clicking the button above")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.selectedCertifications) { certification in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "medal.star.fill")
                                    .foregroundColor(categoryColor(for: certification.category))
                                
                                Text(certification.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button {
                                    if let index = viewModel.selectedCertifications.firstIndex(where: { $0.id == certification.id }) {
                                        viewModel.removeCertification(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Issuer")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(certification.issuer)
                                        .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Category")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(certification.category.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(categoryColor(for: certification.category).opacity(0.2))
                                        .foregroundColor(categoryColor(for: certification.category))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Skills & Expertise")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Add relevant skills and expertise areas that the technician possesses.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button(action: {
                    viewModel.isAddingSkill = true
                }) {
                    Label("Add Custom Skill", systemImage: "plus.circle")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            
            if viewModel.selectedSkills.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No skills added")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add skills by selecting from common skills below or adding custom skills")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Selected Skills")
                        .font(.headline)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.selectedSkills) { skill in
                            SkillChip(skill: skill) {
                                if let index = viewModel.selectedSkills.firstIndex(where: { $0.id == skill.id }) {
                                    viewModel.removeSkill(at: IndexSet(integer: index))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            Divider()
                .padding(.vertical, 10)
            
            VStack(alignment: .leading, spacing: 16) {
            Text("Common Skills")
                    .font(.headline)
            
                FlowLayout(spacing: 10) {
                ForEach(viewModel.predefinedSkills) { skill in
                    if !viewModel.selectedSkills.contains(where: { $0.name == skill.name }) {
                        Button(action: {
                            viewModel.addPredefinedSkill(skill)
                        }) {
                                HStack(spacing: 6) {
                            Text(skill.name)
                                        .font(.subheadline)
                                    
                                    Image(systemName: "plus")
                                .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(20)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Components
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType, field: FormField, errorMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 0) {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusField, equals: field)
                        .submitLabel(getSubmitLabel(for: field))
                        .onSubmit {
                            advanceToNextField(from: field)
                        }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateForm() {
        // Step 1 validation handled separately with isStep1Valid
        
        // Final form validation (all steps)
        isFormValid = isStep1Valid
    }
    
    private func getSubmitLabel(for field: FormField) -> SubmitLabel {
        switch field {
        case .name, .email, .phone:
            return .next
        }
    }
    
    private func advanceToNextField(from currentField: FormField) {
        switch currentField {
        case .name:
            focusField = .email
        case .email:
            focusField = .phone
        case .phone:
            focusField = nil
            if isStep1Valid {
                withAnimation {
                    currentStep = 2
                }
            }
        }
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Personal"
        case 2: return "Certifications"
        case 3: return "Skills"
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
    
    private func categoryColor(for category: Certification.CertificationCategory) -> Color {
        switch category {
        case .technician:
            return .blue
        case .manager:
            return .purple
        case .other:
            return .green
        }
    }
}

struct MaintenanceDetailView: View {
    let person: MaintenancePersonnel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Personal Information") {
                    DetailRow(title: "Full Name", value: person.name)
                    DetailRow(title: "Email", value: person.email)
                    DetailRow(title: "Phone", value: person.phone)
                    DetailRow(title: "Status", value: person.isActive ? "Active" : "Inactive")
                }
                
                Section("Maintenance Information") {
                    DetailRow(title: "ID", value: person.id)
                    DetailRow(title: "Status", value: person.isActive ? "Active" : "Inactive")
                    DetailRow(title: "Hire Date", value: formatDate(person.hireDate))
                }
                
                if !person.certifications.isEmpty {
                    Section("Certifications") {
                        ForEach(person.certifications) { certification in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(certification.name)
                                    .font(.headline)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Issuer")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(certification.issuer)
                                            .font(.subheadline)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(certification.category.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(categoryColor(for: certification.category).opacity(0.2))
                                        .foregroundColor(categoryColor(for: certification.category))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                if !person.skills.isEmpty {
                    Section("Skills & Expertise") {
                        ForEach(person.skills) { skill in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(skill.name)
                                        .font(.headline)
                                    
                                    if skill.experienceYears > 0 {
                                        Text("\(skill.experienceYears) \(skill.experienceYears == 1 ? "year" : "years") experience")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(skill.proficiencyLevel.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(proficiencyColor(for: skill.proficiencyLevel).opacity(0.2))
                                    .foregroundColor(proficiencyColor(for: skill.proficiencyLevel))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Maintenance Details")
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
    
    private func categoryColor(for category: Certification.CertificationCategory) -> Color {
        switch category {
        case .technician:
            return .blue
        case .manager:
            return .purple
        case .other:
            return .green
        }
    }
    
    private func proficiencyColor(for level: Skill.ProficiencyLevel) -> Color {
        switch level {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .purple
        case .expert:
            return .red
        }
    }
}

#Preview {
    MaintenanceManagementView()
        .environmentObject(MaintenanceViewModel())
} 
