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
        isLoading = true
        
        let newPersonnel = MaintenancePersonnel(
            name: name, 
            email: email, 
            phone: phone, 
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
                    
                    // Updated success message without showing the password
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
        isLoading = true
        
        var updatedPersonnel = selectedPersonnel
        updatedPersonnel.name = name
        updatedPersonnel.email = email
        updatedPersonnel.phone = phone
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
} 
