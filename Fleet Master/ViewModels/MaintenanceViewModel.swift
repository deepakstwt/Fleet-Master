import Foundation
import SwiftUI
import Supabase
import MessageUI

class MaintenanceViewModel: ObservableObject, @unchecked Sendable {
    @Published var personnel: [MaintenancePersonnel] = []
    @Published var searchText: String = "" {
        didSet {
            if !searchText.isEmpty && searchText.count > 2 {
                searchDebounceTimer?.invalidate()
                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    self?.searchPersonnel()
                }
            } else if searchText.isEmpty && oldValue.count > 0 {
                // If search was cleared, reload all personnel
                fetchPersonnel()
            }
        }
    }
    @Published var isShowingAddPersonnel = false
    @Published var isShowingEditPersonnel = false
    @Published var selectedPersonnel: MaintenancePersonnel?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Form properties
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var selectedCertifications: [Certification] = []
    @Published var selectedSkills: [Skill] = []
    
    // UI state for certification/skill editing
    @Published var isAddingCertification = false
    @Published var isAddingSkill = false
    
    // Certification form properties
    @Published var certificationName = ""
    @Published var certificationIssuer = ""
    @Published var certificationCategory: Certification.CertificationCategory = .technician
    @Published var certificationDateObtained = Date()
    @Published var certificationHasExpiration = false
    @Published var certificationExpirationDate = Date().addingTimeInterval(365*24*60*60) // 1 year from now
    
    // Skill form properties
    @Published var skillName = ""
    @Published var skillProficiency: Skill.ProficiencyLevel = .intermediate
    @Published var skillYears = 0
    
    @Published var newSkillName = ""
    @Published var newSkillProficiency: Skill.ProficiencyLevel = .intermediate
    @Published var certificationFormData = CertificationFormData()
    
    // Instance of MaintenanceSupabaseManager
    private let maintenanceManager = MaintenanceSupabaseManager.shared
    
    private var searchDebounceTimer: Timer?
    
    // Predefined certifications and skills
    let predefinedCertifications: [Certification] = [
        // Indian Mechanic/Technician Certifications
        Certification(name: "Industrial Training Institute (ITI) - Mechanic Motor Vehicle", 
                      issuer: "Directorate General of Training (DGT), India", 
                      category: .technician),
        
        Certification(name: "Industrial Training Institute (ITI) - Mechanic Diesel", 
                      issuer: "Directorate General of Training (DGT), India", 
                      category: .technician),
        
        Certification(name: "Diploma in Automobile Engineering", 
                      issuer: "All India Council for Technical Education (AICTE)", 
                      category: .technician),
        
        Certification(name: "Automobile Service Technician Certification", 
                      issuer: "Automotive Skills Development Council (ASDC)", 
                      category: .technician),
        
        Certification(name: "Certificate in Auto Electrical and Electronics Repair", 
                      issuer: "Skill Council for Automotive Industry", 
                      category: .technician),
        
        Certification(name: "National Apprenticeship Certificate (NAC) in Mechanic Motor Vehicle", 
                      issuer: "National Council for Vocational Training (NCVT)", 
                      category: .technician),
        
        // Manager/Supervisor certifications
        Certification(name: "Advanced Diploma in Automotive Mechatronics (ADAM)", 
                      issuer: "Mercedes-Benz India", 
                      category: .manager),
        
        Certification(name: "Certified Automotive Fleet Manager", 
                      issuer: "Institute of Road Transport Technology", 
                      category: .manager),
        
        Certification(name: "Certification in Automotive Service Management", 
                      issuer: "Automotive Skills Development Council (ASDC)", 
                      category: .manager),
        
        Certification(name: "Post Graduate Diploma in Automotive Technology", 
                      issuer: "National Automotive Testing and R&D Infrastructure Project (NATRiP)", 
                      category: .manager),
        
        // Other certifications
        Certification(name: "BS-VI Vehicle Maintenance Specialist", 
                      issuer: "Society of Indian Automobile Manufacturers (SIAM)", 
                      category: .other),
        
        Certification(name: "Electric Vehicle Maintenance Technician", 
                      issuer: "Automotive Research Association of India (ARAI)", 
                      category: .other),
        
        Certification(name: "Heavy Commercial Vehicle Maintenance Expert", 
                      issuer: "Association of State Road Transport Undertakings (ASRTU)", 
                      category: .other)
    ]
    
    let predefinedSkills: [Skill] = [
        Skill(name: "Preventive Maintenance", proficiencyLevel: .intermediate),
        Skill(name: "Electrical Troubleshooting", proficiencyLevel: .intermediate),
        Skill(name: "Hydraulic Systems", proficiencyLevel: .intermediate),
        Skill(name: "HVAC Maintenance", proficiencyLevel: .intermediate),
        Skill(name: "Welding", proficiencyLevel: .intermediate),
        Skill(name: "Machining", proficiencyLevel: .intermediate),
        Skill(name: "PLC Programming", proficiencyLevel: .intermediate),
        Skill(name: "Pneumatic Systems", proficiencyLevel: .intermediate),
        Skill(name: "Blueprint Reading", proficiencyLevel: .intermediate),
        Skill(name: "Predictive Maintenance", proficiencyLevel: .intermediate),
        Skill(name: "Equipment Calibration", proficiencyLevel: .intermediate),
        Skill(name: "Mechanical Assembly", proficiencyLevel: .intermediate),
        Skill(name: "Root Cause Analysis", proficiencyLevel: .intermediate)
    ]
    
    var filteredPersonnel: [MaintenancePersonnel] {
        if searchText.isEmpty {
            return personnel
        } else {
            return personnel.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.id.localizedCaseInsensitiveContains(searchText) ||
                person.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Filtered certifications by category for UI
    func certifications(for category: Certification.CertificationCategory) -> [Certification] {
        return predefinedCertifications.filter { $0.category == category }
    }
    
    init() {
        // Load maintenance personnel from Supabase
        fetchPersonnel()
    }
    
    // MARK: - Data Operations
    
    /// Fetch all maintenance personnel from Supabase
    func fetchPersonnel() {
        isLoading = true
        errorMessage = nil
        
        print("Starting maintenance personnel fetch operation...")
        Task {
            do {
                let fetchedPersonnel = try await maintenanceManager.fetchAllPersonnel()
                
                DispatchQueue.main.async {
                    self.personnel = fetchedPersonnel
                    self.isLoading = false
                    print("Successfully loaded \(fetchedPersonnel.count) maintenance personnel")
                }
            } catch let error as NSError where error.domain == "MaintenanceSupabaseManager" && error.code == 404 {
                // Special handling for missing table error
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("Table missing error: \(error.localizedDescription)")
                }
            } catch let error as PostgrestError {
                // Handle specific Postgrest errors
                DispatchQueue.main.async {
                    self.errorMessage = "Supabase error: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Postgrest error: \(error)")
                }
            } catch {
                // Generic error handling
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load maintenance personnel: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error loading maintenance personnel: \(error)")
                }
            }
        }
    }
    
    /// Search maintenance personnel based on search text
    func searchPersonnel() {
        guard !searchText.isEmpty else {
            // If search is empty, just load all maintenance personnel
            fetchPersonnel()
            return
        }
        
        // Only perform search if we have 3 or more characters
        guard searchText.count >= 3 else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Try to search on the backend first
                let searchResults = try await maintenanceManager.searchPersonnel(searchText: searchText)
                
                DispatchQueue.main.async {
                    self.personnel = searchResults
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error searching maintenance personnel: \(error)")
                    
                    // Fall back to local filtering if the remote search fails
                    let searchText = self.searchText.lowercased()
                    self.personnel = self.personnel.filter { person in
                        person.name.localizedCaseInsensitiveContains(searchText) ||
                        person.id.localizedCaseInsensitiveContains(searchText) ||
                        person.email.localizedCaseInsensitiveContains(searchText)
                    }
                }
            }
        }
    }
    
    /// Add a new maintenance personnel to Supabase
    func addPersonnel() {
        // Validate form inputs first
        if !isPersonnelFormValid() {
            return
        }
        
        isLoading = true
        
        // Clean up input values
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newPersonnel = MaintenancePersonnel(
            name: cleanName, 
            email: cleanEmail, 
            phone: cleanPhone, 
            hireDate: Date(),
            isActive: true,
            certifications: selectedCertifications,
            skills: selectedSkills
        )
        
        Task {
            do {
                let createdPersonnel = try await maintenanceManager.addPersonnel(newPersonnel)
                
                // Send the temporary password to the maintenance personnel's email
                EmailService.shared.sendPasswordEmail(
                    to: createdPersonnel.email,
                    name: createdPersonnel.name,
                    password: newPersonnel.password // Use the password from our newPersonnel object since it's not returned from the server
                )
                
                DispatchQueue.main.async {
                    self.personnel.append(createdPersonnel)
                    self.resetForm()
                    self.isLoading = false
                    
                    // Updated success message without showing the UUID
                    self.alertMessage = "Maintenance personnel added successfully! A welcome email with login details has been sent to \(createdPersonnel.email)."
                    self.showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to add maintenance personnel: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error adding maintenance personnel: \(error)")
                }
            }
        }
    }
    
    /// Update an existing maintenance personnel in Supabase
    func updatePersonnel() {
        guard let selectedPersonnel = selectedPersonnel else { return }
        
        // Validate form inputs first
        if !isPersonnelFormValid() {
            return
        }
        
        isLoading = true
        
        // Clean up input values
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var updatedPersonnel = selectedPersonnel
        updatedPersonnel.name = cleanName
        updatedPersonnel.email = cleanEmail
        updatedPersonnel.phone = cleanPhone
        updatedPersonnel.certifications = selectedCertifications
        updatedPersonnel.skills = selectedSkills
        
        Task {
            do {
                let personnel = try await maintenanceManager.updatePersonnel(updatedPersonnel)
                
                DispatchQueue.main.async {
                    if let index = self.personnel.firstIndex(where: { $0.id == personnel.id }) {
                        self.personnel[index] = personnel
                    }
                    self.resetForm()
                    self.isShowingEditPersonnel = false
                    self.selectedPersonnel = nil
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update maintenance personnel: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error updating maintenance personnel: \(error)")
                }
            }
        }
    }
    
    /// Toggle the active status of a maintenance personnel in Supabase
    func togglePersonnelStatus(person: MaintenancePersonnel) {
        isLoading = true
        
        Task {
            do {
                let updatedPersonnel = try await maintenanceManager.togglePersonnelStatus(personId: person.id, isActive: !person.isActive)
                
                DispatchQueue.main.async {
                    if let index = self.personnel.firstIndex(where: { $0.id == updatedPersonnel.id }) {
                        self.personnel[index] = updatedPersonnel
                    }
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to update personnel status: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error updating personnel status: \(error)")
                }
            }
        }
    }
    
    func selectPersonnelForEdit(person: MaintenancePersonnel) {
        selectedPersonnel = person
        name = person.name
        email = person.email
        phone = person.phone
        selectedCertifications = person.certifications
        selectedSkills = person.skills
        isShowingEditPersonnel = true
    }
    
    func resetForm() {
        name = ""
        email = ""
        phone = ""
        selectedCertifications = []
        selectedSkills = []
        isShowingAddPersonnel = false
        
        // Reset certification and skill form data
        resetCertificationForm()
        resetSkillForm()
    }
    
    // Certification management methods
    func addSelectedCertification() {
        let certification = Certification(
            name: certificationFormData.name,
            issuer: certificationFormData.issuer,
            category: certificationFormData.category
        )
        selectedCertifications.append(certification)
        certificationFormData = CertificationFormData()
        isAddingCertification = false
    }
    
    // Method to add multiple predefined certifications at once
    func addMultipleCertifications(_ certifications: [Certification]) {
        for certification in certifications {
            if !selectedCertifications.contains(where: { $0.id == certification.id }) {
                selectedCertifications.append(certification)
            }
        }
        isAddingCertification = false
    }
    
    // New method to add a predefined certification
    func addPredefinedCertification(_ certification: Certification) {
        if !selectedCertifications.contains(where: { $0.id == certification.id }) {
            selectedCertifications.append(certification)
        }
    }
    
    func addCertification() {
        let certification = Certification(
            name: certificationName,
            issuer: certificationIssuer,
            category: certificationCategory
        )
        selectedCertifications.append(certification)
        resetCertificationForm()
        isAddingCertification = false
    }
    
    func resetCertificationForm() {
        certificationName = ""
        certificationIssuer = ""
        certificationCategory = .technician
        certificationDateObtained = Date()
        certificationHasExpiration = false
        certificationExpirationDate = Date().addingTimeInterval(365*24*60*60)
    }
    
    func removeCertification(at offsets: IndexSet) {
        selectedCertifications.remove(atOffsets: offsets)
    }
    
    // Skills management methods
    func addCustomSkill() {
        if !newSkillName.isEmpty {
            let skill = Skill(name: newSkillName, proficiencyLevel: newSkillProficiency, isCustom: true)
            selectedSkills.append(skill)
            newSkillName = ""
            newSkillProficiency = .intermediate
            isAddingSkill = false
        }
    }
    
    func addSkill() {
        if !skillName.isEmpty {
            let skill = Skill(name: skillName, proficiencyLevel: skillProficiency, experienceYears: skillYears, isCustom: true)
            selectedSkills.append(skill)
            resetSkillForm()
            isAddingSkill = false
        }
    }
    
    func resetSkillForm() {
        skillName = ""
        skillProficiency = .intermediate
        skillYears = 0
    }
    
    func addPredefinedSkill(_ skill: Skill) {
        if !selectedSkills.contains(where: { $0.name == skill.name }) {
            selectedSkills.append(skill)
        }
    }
    
    func removeSkill(at offsets: IndexSet) {
        selectedSkills.remove(atOffsets: offsets)
    }
    
    // Form data structure for certifications
    struct CertificationFormData {
        var name: String = ""
        var issuer: String = ""
        var category: Certification.CertificationCategory = .technician
    }
    
    /// Run a test function to check Supabase connection and database setup
    func testSupabaseSetup() {
        isLoading = true
        errorMessage = nil
        
        print("Testing Supabase setup for maintenance personnel...")
        Task {
            do {
                // First check if the table exists
                let tableExists = try await maintenanceManager.checkTableExists()
                
                if !tableExists {
                    // Table doesn't exist, we need to create it
                    DispatchQueue.main.async {
                        self.errorMessage = "Maintenance personnel table doesn't exist in Supabase. Please run the SQL setup script from SUPABASE_SETUP.md."
                        self.isLoading = false
                    }
                    return
                }
                
                // Try to fetch a single row to test
                do {
                    print("Testing query on maintenance_personnel table...")
                    let response = try await maintenanceManager.supabase
                        .from("maintenance_personnel")
                        .select()
                        .limit(1)
                        .execute()
                    
                    print("Test query response: \(response)")
                    let jsonData = response.data
                    
                    // Print full JSON for debugging
                    if let jsonStr = String(data: jsonData, encoding: .utf8) {
                        print("Full response data: \(jsonStr)")
                        
                        // Try to parse as dictionary to examine structure
                        if let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                            print("JSON structure analysis:")
                            
                            if let firstRecord = jsonDict.first {
                                // Log top-level keys
                                print("Top-level keys: \(firstRecord.keys.joined(separator: ", "))")
                                
                                // If certifications exist, check their structure
                                if let certs = firstRecord["certifications"] as? [[String: Any]], !certs.isEmpty {
                                    print("Certification keys: \(certs.first?.keys.joined(separator: ", ") ?? "none")")
                                }
                                
                                // If skills exist, check their structure
                                if let skills = firstRecord["skills"] as? [[String: Any]], !skills.isEmpty {
                                    print("Skill keys: \(skills.first?.keys.joined(separator: ", ") ?? "none")")
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.alertMessage = "Supabase connection test successful! The maintenance_personnel table exists and can be queried."
                        self.showAlert = true
                        self.isLoading = false
                        
                        // Try to parse JSON with different date format
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .custom { decoder in
                            let container = try decoder.singleValueContainer()
                            
                            // Try to decode as string first
                            do {
                                let value = try container.decode(String.self)
                                print("Decoding date string: \(value)")
                                
                                // Try multiple formatters
                                let formatters = [
                                    // ISO8601 with fractional seconds
                                    { () -> DateFormatter in
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                                        return formatter
                                    }(),
                                    // ISO8601 without fractional seconds
                                    { () -> DateFormatter in
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                                        return formatter
                                    }(),
                                    // PostgreSQL timestamp format
                                    { () -> DateFormatter in
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                                        return formatter
                                    }()
                                ]
                                
                                for formatter in formatters {
                                    if let date = formatter.date(from: value) {
                                        print("Successfully parsed date with format: \(formatter.dateFormat ?? "unknown")")
                                        return date
                                    }
                                }
                                
                                throw DecodingError.dataCorruptedError(in: container, 
                                                                      debugDescription: "Cannot decode date string \(value)")
                            } catch {
                                // If it's not a string, try as a timestamp
                                let timestamp = try container.decode(Double.self)
                                return Date(timeIntervalSince1970: timestamp)
                            }
                        }
                        
                        do {
                            let testPersonnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
                            print("Successful test decode with custom formatter: \(testPersonnel.count) record(s)")
                            
                            // If successful, try to fetch all personnel again
                            self.fetchPersonnel()
                        } catch {
                            print("Test decode failed: \(error)")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        let errorDetails = "Error details: \(error)"
                        print(errorDetails)
                        self.errorMessage = "Error testing table query: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let errorDetails = "Error details: \(error)"
                    print(errorDetails)
                    self.errorMessage = "Error testing Supabase setup: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func getCertificationNames() -> [String] {
        return selectedCertifications.map { $0.name }
    }
    
    func getSkillNames() -> [String] {
        return selectedSkills.map { $0.name }
    }
    
    // MARK: - Validation Methods
    
    // Validate if a phone number matches Indian format
    func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Indian phone numbers are typically 10 digits
        let phoneRegex = #"^\d{10}$"#
        return phoneNumber.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    // Validate if an email is properly formatted
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    // Check if entire maintenance personnel form is valid
    func isPersonnelFormValid() -> Bool {
        // Name validation
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Name is required"
            return false
        }
        
        // Email validation
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Email address is required"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        // Phone validation
        if phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Phone number is required"
            return false
        }
        
        if !isValidPhoneNumber(phone) {
            errorMessage = "Please enter a valid 10-digit Indian phone number"
            return false
        }
        
        // At least one certification and skill is required
        if selectedCertifications.isEmpty {
            errorMessage = "At least one certification must be selected"
            return false
        }
        
        if selectedSkills.isEmpty {
            errorMessage = "At least one skill must be selected"
            return false
        }
        
        return true
    }
    
    // Static help text for maintenance personnel fields
    static let phoneNumberHelpText = """
    Indian phone number format:
    • Must be exactly 10 digits
    • Should not include the country code (+91)
    • Example: 9876543210
    """
    // MARK: - Driver Maintenance Requests
    
    @Published var driverMaintenanceRequests: [DriverMaintenanceRequest] = []
    
    /// Fetch driver maintenance requests from Supabase
    func fetchDriverMaintenanceRequests() {
        isLoading = true
        errorMessage = nil
        
        print("Starting driver maintenance requests fetch operation...")
        Task {
            do {
                let fetchedRequests = try await DriverMaintenanceSupabaseManager.shared.fetchAllDriverMaintenanceRequests()
                
                DispatchQueue.main.async {
                    self.driverMaintenanceRequests = fetchedRequests
                    self.isLoading = false
                    print("Successfully loaded \(fetchedRequests.count) driver maintenance requests")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load driver maintenance requests: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error loading driver maintenance requests: \(error)")
                }
            }
        }
    }
    
    /// Get all driver maintenance requests converted to MaintenanceRequest format for the dashboard
    func getAllDriverMaintenanceRequests(vehicles: [Vehicle]) -> [MaintenanceRequest] {
        print("Converting \(driverMaintenanceRequests.count) driver requests to maintenance requests")
        print("Available vehicles: \(vehicles.count)")
        
        // Log vehicle IDs for debugging
        for vehicle in vehicles.prefix(5) {
            print("Vehicle available for matching: \(vehicle.id) - \(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
        }
        
        if driverMaintenanceRequests.isEmpty {
            print("⚠️ No driver maintenance requests found to convert")
        } else {
            // Log the first few driver requests
            for request in driverMaintenanceRequests.prefix(3) {
                print("Driver request to convert: ID: \(request.id), Vehicle ID: \(request.vehicleId), Problem: \(request.problem)")
            }
        }
        
        let requests = driverMaintenanceRequests.compactMap { driverRequest -> MaintenanceRequest? in
            let request = convertToMaintenanceRequest(driverRequest: driverRequest, vehicles: vehicles)
            if request == nil {
                print("❌ Failed to convert driver request: \(driverRequest.id) for vehicle \(driverRequest.vehicleId)")
                
                // Try to understand why conversion failed
                if !vehicles.contains(where: { $0.id == driverRequest.vehicleId }) {
                    print("  - Vehicle ID \(driverRequest.vehicleId) not found in available vehicles")
                }
            }
            return request
        }
        
        print("✅ Converted \(requests.count)/\(driverMaintenanceRequests.count) driver maintenance requests")
        
        // Log successful conversions
        for request in requests.prefix(3) {
            print("  ✓ Converted request: \(request.id) for vehicle \(request.vehicle.registrationNumber)")
        }
        
        return requests
    }
    
    /// Convert DriverMaintenanceRequest to MaintenanceRequest for the dashboard cards
    /// - Parameter request: The driver maintenance request to convert
    /// - Returns: A MaintenanceRequest object
    func convertToMaintenanceRequest(driverRequest: DriverMaintenanceRequest, vehicles: [Vehicle]) -> MaintenanceRequest? {
        // Find the associated vehicle
        guard let vehicle = vehicles.first(where: { $0.id == driverRequest.vehicleId }) else {
            print("  - Could not find vehicle with ID: \(driverRequest.vehicleId) for request \(driverRequest.id)")
            return nil
        }
        
        // Default personnel if not assigned
        let defaultPersonnel = MaintenancePersonnel(
            id: "unassigned",
            name: "Not Assigned",
            email: "",
            phone: "",
            hireDate: Date(),
            isActive: true,
            password: "",
            certifications: [],
            skills: []
        )
        
        // Try to find assigned personnel
        let assignedPersonnel: MaintenancePersonnel
        if let personnelId = driverRequest.assignedPersonnelId,
           let foundPersonnel = personnel.first(where: { $0.id == personnelId }) {
            print("  - Using assigned personnel: \(foundPersonnel.name) for request \(driverRequest.id)")
            assignedPersonnel = foundPersonnel
        } else {
            print("  - Using default personnel for request \(driverRequest.id)")
            assignedPersonnel = defaultPersonnel
        }
        
        // Create the maintenance request
        let maintenanceRequest = MaintenanceRequest(
            id: driverRequest.id,
            vehicle: vehicle,
            description: driverRequest.problem,
            dueDateTimestamp: driverRequest.scheduleDate?.timeIntervalSince1970 ?? driverRequest.createdAt.timeIntervalSince1970,
            createdTimestamp: driverRequest.createdAt.timeIntervalSince1970,
            isDriverRequest: true,
            isScheduled: driverRequest.accepted,
            personnel: assignedPersonnel
        )
        
        print("  + Successfully created maintenance request from driver request \(driverRequest.id)")
        return maintenanceRequest
    }
    
    // MARK: - Dashboard Integration
    
    /// Get all driver maintenance requests converted to MaintenanceRequest format for the dashboard
//    func getAllDriverMaintenanceRequests(vehicles: [Vehicle]) -> [MaintenanceRequest] {
//        return driverMaintenanceRequests.compactMap { convertToMaintenanceRequest(driverRequest: $0, vehicles: vehicles) }
//    }
    
    /// Get pending (unscheduled) driver maintenance requests for the dashboard
    func getPendingMaintenanceRequests(vehicles: [Vehicle]) -> [MaintenanceRequest] {
        // First, get scheduled maintenance based on vehicle next service dates
        let scheduledMaintenance = generateScheduledMaintenanceRequests(vehicles: vehicles)
        
        // Then get driver-submitted maintenance requests
        let driverRequests = getAllDriverMaintenanceRequests(vehicles: vehicles)
        
        // Combine both types
        return scheduledMaintenance + driverRequests
    }
    
    /// Generate maintenance requests based on vehicle service schedules
    private func generateScheduledMaintenanceRequests(vehicles: [Vehicle]) -> [MaintenanceRequest] {
        var requests: [MaintenanceRequest] = []
        
        // Get default maintenance personnel (first active one)
        let defaultPersonnel = personnel.first { $0.isActive } ?? MaintenancePersonnel(
            id: "unassigned",
            name: "Not Assigned",
            email: "",
            phone: "",
            hireDate: Date(),
            isActive: true,
            password: "",
            certifications: [],
            skills: []
        )
        
        // Create maintenance requests for vehicles with upcoming or overdue service
        for vehicle in vehicles {
            if let nextServiceDue = vehicle.nextServiceDue {
                // Check if service is due within the next 7 days or overdue
                let daysUntilService = Calendar.current.dateComponents([.day], from: Date(), to: nextServiceDue).day ?? 0
                
                if daysUntilService <= 7 {
                    let request = MaintenanceRequest(
                        id: "scheduled-\(vehicle.id)",
                        vehicle: vehicle,
                        description: "Scheduled maintenance for \(vehicle.make) \(vehicle.model)",
                        dueDateTimestamp: nextServiceDue.timeIntervalSince1970,
                        createdTimestamp: Date().timeIntervalSince1970,
                        isDriverRequest: false,
                        isScheduled: false,
                        personnel: defaultPersonnel
                    )
                    
                    requests.append(request)
                }
            }
        }
        
        return requests
    }
    
    /// Fetch all maintenance requests for the dashboard
    func fetchMaintenanceRequests() async {
        Task {
            // Fetch driver-submitted maintenance requests
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.fetchDriverMaintenanceRequestsAsync()
                }
                group.addTask {
                    await self.fetchPersonnelAsync()
                }
            }
        }
    }
    
    /// Async wrapper for fetchDriverMaintenanceRequests
    private func fetchDriverMaintenanceRequestsAsync() async {
        await withCheckedContinuation { continuation in
            fetchDriverMaintenanceRequests()
            // Continue after a short delay to ensure the refresh indicator shows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
    
    /// Async wrapper for fetchPersonnel
    private func fetchPersonnelAsync() async {
        await withCheckedContinuation { continuation in
            fetchPersonnel()
            // Continue after a short delay to ensure the refresh indicator shows
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
} 
