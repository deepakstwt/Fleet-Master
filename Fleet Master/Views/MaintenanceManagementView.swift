import SwiftUI

struct MaintenanceManagementView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @State private var isShowingDetail = false
    @State private var selectedPersonnel: MaintenancePersonnel?
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search and Filter Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search maintenance personnel...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        viewModel.isShowingAddPersonnel = true
                    }) {
                        Label("Add Personnel", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                // Maintenance Personnel List
                List {
                    ForEach(viewModel.filteredPersonnel) { person in
                        MaintenanceRow(person: person)
                            .onTapGesture {
                                selectedPersonnel = person
                                isShowingDetail = true
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.togglePersonnelStatus(person: person)
                                } label: {
                                    Label(person.isActive ? "Disable" : "Enable", 
                                          systemImage: person.isActive ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.checkmark")
                                }
                                .tint(person.isActive ? .red : .green)
                                
                                Button {
                                    viewModel.selectPersonnelForEdit(person: person)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Maintenance Management")
            .sheet(isPresented: $viewModel.isShowingAddPersonnel) {
                AddMaintenanceView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditPersonnel) {
                EditMaintenanceView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $isShowingDetail) {
                if let person = selectedPersonnel {
                    MaintenanceDetailView(person: person)
                }
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

struct MaintenanceRow: View {
    let person: MaintenancePersonnel
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 40))
                .foregroundColor(person.isActive ? .orange : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)
                    .foregroundColor(person.isActive ? .primary : .secondary)
                
                Text("ID: \(person.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(person.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Specialization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(person.specialization)
                    .font(.subheadline)
                
                Text(person.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(person.isActive ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(person.isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(5)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddMaintenanceView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack {
                    ForEach(0..<3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .overlay(Text("\(step + 1)").foregroundColor(step <= currentStep ? .white : .gray))
                        
                        if step < 2 {
                            Rectangle()
                                .fill(step < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                
                // Content based on current step
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0:
                            // Basic Info
                            basicInfoForm
                        case 1:
                            // Certifications
                            certificationsForm
                        case 2:
                            // Skills
                            skillsForm
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < 2 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentStep == 0 && (viewModel.name.isEmpty || viewModel.email.isEmpty || 
                             viewModel.phone.isEmpty || viewModel.specialization.isEmpty))
                    } else {
                        Button("Complete") {
                            viewModel.addPersonnel()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Maintenance Personnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.isAddingCertification) {
                addCertificationView
            }
            .sheet(isPresented: $viewModel.isAddingSkill) {
                addSkillView
            }
        }
    }
    
    // Step 1: Basic Info
    private var basicInfoForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Basic Information")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Full Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Full Name", text: $viewModel.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.name)
            }
            
            VStack(alignment: .leading) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
            }
            
            VStack(alignment: .leading) {
                Text("Phone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Phone", text: $viewModel.phone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            
            VStack(alignment: .leading) {
                Text("Specialization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Specialization", text: $viewModel.specialization)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    // Step 2: Certifications
    private var certificationsForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Certifications")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.isAddingCertification = true
                }) {
                    Label("Add", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
            
            if viewModel.selectedCertifications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "certificate")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No certifications added")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ForEach(viewModel.selectedCertifications.indices, id: \.self) { index in
                    certificateCard(for: viewModel.selectedCertifications[index])
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.removeCertification(at: IndexSet(integer: index))
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
            
            Divider()
                .padding(.vertical)
            
            Group {
                Text("Technician Certifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(viewModel.certifications(for: .technician)) { cert in
                    certificationRow(cert)
                }
                
                Text("Manager/Supervisor Certifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                ForEach(viewModel.certifications(for: .manager)) { cert in
                    certificationRow(cert)
                }
                
                Text("Other Certifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                ForEach(viewModel.certifications(for: .other)) { cert in
                    certificationRow(cert)
                }
            }
        }
    }
    
    // Step 3: Skills
    private var skillsForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Skills & Expertise")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.isAddingSkill = true
                }) {
                    Label("Add", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
            
            if viewModel.selectedSkills.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No skills added")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(viewModel.selectedSkills.indices, id: \.self) { index in
                        skillChip(for: viewModel.selectedSkills[index], index: index)
                    }
                }
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Common Skills")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.predefinedSkills) { skill in
                    if !viewModel.selectedSkills.contains(where: { $0.name == skill.name }) {
                        Button(action: {
                            viewModel.addPredefinedSkill(skill)
                        }) {
                            Text(skill.name)
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(15)
                        }
                    }
                }
            }
        }
    }
    
    // Certification row for selection
    private func certificationRow(_ certification: Certification) -> some View {
        Button(action: {
            if !viewModel.selectedCertifications.contains(where: { $0.id == certification.id }) {
                viewModel.selectedCertifications.append(certification)
            }
        }) {
            HStack {
                Text(certification.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if viewModel.selectedCertifications.contains(where: { $0.id == certification.id }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
    }
    
    // Certification card for display
    private func certificateCard(for certification: Certification) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(certification.name)
                .font(.headline)
                .lineLimit(2)
            
            Text("Issuer: \(certification.issuer)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Category: \(certification.category.rawValue)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor(for: certification.category).opacity(0.2))
                    .foregroundColor(categoryColor(for: certification.category))
                    .cornerRadius(5)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // Skill chip
    private func skillChip(for skill: Skill, index: Int) -> some View {
        HStack {
            Text(skill.name)
                .font(.caption)
            
            Spacer()
            
            Button(action: {
                viewModel.removeSkill(at: IndexSet(integer: index))
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Add certification view
    private var addCertificationView: some View {
        NavigationStack {
            Form {
                Section("Certification Details") {
                    TextField("Name", text: $viewModel.certificationFormData.name)
                    TextField("Issuer", text: $viewModel.certificationFormData.issuer)
                    
                    DatePicker("Date Obtained", selection: $viewModel.certificationFormData.dateObtained, displayedComponents: .date)
                    
                    Toggle("Has Expiration Date", isOn: $viewModel.certificationFormData.hasExpirationDate)
                    
                    if viewModel.certificationFormData.hasExpirationDate {
                        let binding = Binding<Date>(
                            get: { viewModel.certificationFormData.expirationDate ?? Date() },
                            set: { viewModel.certificationFormData.expirationDate = $0 }
                        )
                        
                        DatePicker("Expiration Date", selection: binding, displayedComponents: .date)
                    }
                    
                    Picker("Category", selection: $viewModel.certificationFormData.category) {
                        ForEach(Certification.CertificationCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
                
                Section {
                    Button("Add") {
                        viewModel.addSelectedCertification()
                    }
                    .disabled(viewModel.certificationFormData.name.isEmpty || viewModel.certificationFormData.issuer.isEmpty)
                }
            }
            .navigationTitle("Add Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isAddingCertification = false
                    }
                }
            }
        }
    }
    
    // Add skill view
    private var addSkillView: some View {
        NavigationStack {
            Form {
                Section("Custom Skill") {
                    TextField("Skill Name", text: $viewModel.newSkillName)
                    
                    Picker("Proficiency Level", selection: $viewModel.newSkillProficiency) {
                        ForEach(Skill.ProficiencyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                Section {
                    Button("Add") {
                        viewModel.addCustomSkill()
                    }
                    .disabled(viewModel.newSkillName.isEmpty)
                }
            }
            .navigationTitle("Add Custom Skill")
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
    
    // Helper for certification category colors
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

struct EditMaintenanceView: View {
    @EnvironmentObject private var viewModel: MaintenanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personnel Information") {
                    TextField("Full Name", text: $viewModel.name)
                        .textContentType(.name)
                    
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    TextField("Phone", text: $viewModel.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("Maintenance Information") {
                    TextField("Specialization", text: $viewModel.specialization)
                }
                
                Section {
                    Button("Update Personnel") {
                        viewModel.updatePersonnel()
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty || viewModel.email.isEmpty || 
                             viewModel.phone.isEmpty || viewModel.specialization.isEmpty)
                }
            }
            .navigationTitle("Edit Maintenance Personnel")
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
                }
                
                Section("Maintenance Information") {
                    DetailRow(title: "ID", value: person.id)
                    DetailRow(title: "Specialization", value: person.specialization)
                    DetailRow(title: "Status", value: person.isActive ? "Active" : "Inactive")
                    DetailRow(title: "Hire Date", value: formatDate(person.hireDate))
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
}

struct DetailRow: View {
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
    MaintenanceManagementView()
        .environmentObject(MaintenanceViewModel())
} 