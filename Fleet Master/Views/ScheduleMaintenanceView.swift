import SwiftUI
import Foundation

struct ScheduleMaintenanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var maintenanceViewModel: MaintenanceViewModel
    let vehicle: Vehicle
    var initialMaintenanceType: MaintenanceType? = nil
    var driverId: String? = nil
    
    @State private var selectedMaintenanceType: MaintenanceType = .routine
    @State private var selectedPersonnel: MaintenancePersonnel?
    @State private var selectedDate = Date()
    @State private var problem = ""
    @State private var priority: Priority = .medium
    @State private var note = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showPersonnelSheet = false
    
    // Initializer with default parameters
    init(vehicle: Vehicle, initialMaintenanceType: MaintenanceType? = nil, driverId: String? = nil, initialProblem: String = "") {
        self.vehicle = vehicle
        self.initialMaintenanceType = initialMaintenanceType
        self.driverId = driverId
        _problem = State(initialValue: initialProblem)
        _selectedMaintenanceType = State(initialValue: initialMaintenanceType ?? .routine)
    }
    
    enum MaintenanceType: String, CaseIterable {
        case routine = "Maintenance"
        case repair = "Repair"
        
        var icon: String {
            switch self {
            case .routine: return "wrench.and.screwdriver"
            case .repair: return "hammer"
            }
        }
    }
    
    enum Priority: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .green
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Vehicle Info Card
                    vehicleInfoCard
                    
                    // Maintenance Type Selection
                    maintenanceTypeSection
                    
                    // Problem Description
                    problemSection
                    
                    // Priority Selection
                    prioritySection
                    
                    // Personnel Selection
                    personnelSection
                                        
                    // Notes
                    notesSection
                }
                .padding()
            }
            .navigationTitle("Schedule Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        scheduleMaintenance()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .sheet(isPresented: $showPersonnelSheet) {
                PersonnelSelectionView(selectedPersonnel: $selectedPersonnel)
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var vehicleInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.make + " " + vehicle.model)
                        .font(.headline)
                    
                    Text("Registration: \(vehicle.registrationNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var maintenanceTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maintenance Type")
                .font(.headline)
            
            Menu {
                ForEach(MaintenanceType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedMaintenanceType = type
                    }) {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }
            } label: {
                HStack {
                    Label(selectedMaintenanceType.rawValue, systemImage: selectedMaintenanceType.icon)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    private var problemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Problem Description")
                .font(.headline)
            
            TextEditor(text: $problem)
                .frame(height: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priority")
                .font(.headline)
            
            Menu {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button(action: {
                        self.priority = priority
                    }) {
                        Label(priority.rawValue, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(priority.color)
                    }
                }
            } label: {
                HStack {
                    Label(priority.rawValue, systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(priority.color)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    private var personnelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assign Personnel")
                .font(.headline)
            
            Button(action: {
                showPersonnelSheet = true
            }) {
                HStack {
                    if let selected = selectedPersonnel {
                        Label(selected.name, systemImage: "person.fill")
                    } else {
                        Label("Select Maintenance Personnel", systemImage: "person.2.fill")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Notes")
                .font(.headline)
            
            TextEditor(text: $note)
                .frame(height: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private var isFormValid: Bool {
        !problem.isEmpty && selectedPersonnel != nil
    }
    
    private func scheduleMaintenance() {
        guard let personnel = selectedPersonnel else { return }
        
        isLoading = true
        
        Task {
            do {
                var maintenanceVehicle = MaintenanceVehicle(
                    id: UUID(),
                    ticketNo: "",  // This will be set by the SupabaseManager
                    registrationNumber: vehicle.registrationNumber,
                    problem: problem,
                    priority: MaintenanceVehicle.Priority(rawValue: priority.rawValue) ?? .medium,
                    maintenanceNote: note,
                    type: MaintenanceVehicle.MaintenanceType(rawValue: selectedMaintenanceType.rawValue) ?? .routine,
                    assignedPersonnelId: personnel.id,
                    driverId: driverId // Pass the driver ID if available
                )
                
                try await SupabaseManager.shared.scheduleMaintenance(&maintenanceVehicle)
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Maintenance scheduled successfully"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to schedule maintenance: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct PersonnelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var maintenanceViewModel: MaintenanceViewModel
    @Binding var selectedPersonnel: MaintenancePersonnel?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Text("Select Personnel")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(maintenanceViewModel.personnel.filter { $0.isActive }) { person in
                        personnelCard(person)
                    }
                }
                .padding()
            }
        }
    }
    
    private func personnelCard(_ person: MaintenancePersonnel) -> some View {
        Button {
            selectedPersonnel = person
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(selectedPersonnel?.id == person.id ? Color.blue : Color(.systemGray6))
                        .frame(width: 50, height: 50)
                    
                    Text(person.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(selectedPersonnel?.id == person.id ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(person.certifications.first?.name ?? "Technician")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedPersonnel?.id == person.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPersonnel?.id == person.id ? Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPersonnel?.id == person.id ? Color.blue : Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 
