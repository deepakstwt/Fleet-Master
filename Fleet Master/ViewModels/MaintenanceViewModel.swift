import Foundation
import SwiftUI

class MaintenanceViewModel: ObservableObject {
    @Published var personnel: [MaintenancePersonnel] = []
    @Published var searchText: String = ""
    @Published var isShowingAddPersonnel = false
    @Published var isShowingEditPersonnel = false
    @Published var selectedPersonnel: MaintenancePersonnel?
    @Published var alertMessage = ""
    @Published var showAlert = false
    
    // Form properties
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var specialization = ""
    @Published var selectedCertifications: [Certification] = []
    @Published var selectedSkills: [Skill] = []
    
    // UI state for certification/skill editing
    @Published var isAddingCertification = false
    @Published var isAddingSkill = false
    @Published var newSkillName = ""
    @Published var newSkillProficiency: Skill.ProficiencyLevel = .intermediate
    @Published var certificationFormData = CertificationFormData()
    
    // Predefined certifications and skills
    let predefinedCertifications: [Certification] = [
        // Technician certifications
        Certification(name: "Certified Maintenance & Reliability Technician (CMRT)", 
                      issuer: "Society for Maintenance & Reliability Professionals (SMRP)", 
                      dateObtained: Date(), 
                      category: .technician),
        
        Certification(name: "Certified Maintenance & Reliability Professional (CMRP)", 
                      issuer: "Society for Maintenance & Reliability Professionals (SMRP)", 
                      dateObtained: Date(), 
                      category: .technician),
        
        Certification(name: "Certified Manager of Maintenance (CMM)", 
                      issuer: "National Center for Housing Management", 
                      dateObtained: Date(), 
                      category: .technician),
        
        Certification(name: "Omnex Quality Academy (OQA) Certified Maintenance Engineer (CME)", 
                      issuer: "Omnex Quality Academy", 
                      dateObtained: Date(), 
                      category: .technician),
        
        // Manager/Supervisor certifications
        Certification(name: "Certified Maintenance & Reliability Professional (CMRP)", 
                      issuer: "Society for Maintenance & Reliability Professionals (SMRP)", 
                      dateObtained: Date(), 
                      category: .manager),
        
        Certification(name: "Certified Manager of Maintenance (CMM)", 
                      issuer: "National Center for Housing Management", 
                      dateObtained: Date(), 
                      category: .manager),
        
        Certification(name: "Certified Plant Engineer (CPE)", 
                      issuer: "Association for Facilities Engineering", 
                      dateObtained: Date(), 
                      category: .manager),
        
        Certification(name: "SAP PM Certification", 
                      issuer: "SAP", 
                      dateObtained: Date(), 
                      category: .manager),
        
        // Other certifications
        Certification(name: "Aircraft Maintenance Engineering (AME)", 
                      issuer: "Federal Aviation Administration", 
                      dateObtained: Date(), 
                      category: .other),
        
        Certification(name: "HVAC Excellence Certification", 
                      issuer: "HVAC Excellence", 
                      dateObtained: Date(), 
                      category: .other),
        
        Certification(name: "Building Systems Maintenance Certificate (BSMC)", 
                      issuer: "BOMI International", 
                      dateObtained: Date(), 
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
                person.email.localizedCaseInsensitiveContains(searchText) ||
                person.specialization.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Filtered certifications by category for UI
    func certifications(for category: Certification.CertificationCategory) -> [Certification] {
        return predefinedCertifications.filter { $0.category == category }
    }
    
    init() {
        // For demo purposes, add some sample maintenance personnel
        addSamplePersonnel()
    }
    
    func addSamplePersonnel() {
        personnel = [
            MaintenancePersonnel(
                name: "Mike Williams", 
                email: "mike.w@fleet.com", 
                phone: "555-222-3333", 
                specialization: "Engine Repair",
                certifications: [predefinedCertifications[0], predefinedCertifications[3]],
                skills: [predefinedSkills[0], predefinedSkills[1], predefinedSkills[4]]
            ),
            MaintenancePersonnel(
                name: "Sarah Johnson", 
                email: "sarah.j@fleet.com", 
                phone: "555-444-5555", 
                specialization: "Electrical Systems",
                certifications: [predefinedCertifications[4], predefinedCertifications[6]],
                skills: [predefinedSkills[1], predefinedSkills[6], predefinedSkills[8]]
            ),
            MaintenancePersonnel(
                name: "David Lee", 
                email: "david.l@fleet.com", 
                phone: "555-666-7777", 
                specialization: "Brake Systems",
                certifications: [predefinedCertifications[2]],
                skills: [predefinedSkills[2], predefinedSkills[7], predefinedSkills[11]]
            )
        ]
    }
    
    func addPersonnel() {
        let newPersonnel = MaintenancePersonnel(
            name: name, 
            email: email, 
            phone: phone, 
            specialization: specialization,
            certifications: selectedCertifications,
            skills: selectedSkills
        )
        
        personnel.append(newPersonnel)
        resetForm()
        
        alertMessage = "Maintenance personnel added successfully!\nID: \(newPersonnel.id)\nPassword: \(newPersonnel.password)"
        showAlert = true
    }
    
    func updatePersonnel() {
        guard let selectedPersonnel = selectedPersonnel,
              let index = personnel.firstIndex(where: { $0.id == selectedPersonnel.id }) else { return }
        
        personnel[index].name = name
        personnel[index].email = email
        personnel[index].phone = phone
        personnel[index].specialization = specialization
        personnel[index].certifications = selectedCertifications
        personnel[index].skills = selectedSkills
        
        resetForm()
        isShowingEditPersonnel = false
        self.selectedPersonnel = nil
    }
    
    func togglePersonnelStatus(person: MaintenancePersonnel) {
        guard let index = personnel.firstIndex(where: { $0.id == person.id }) else { return }
        personnel[index].isActive.toggle()
    }
    
    func selectPersonnelForEdit(person: MaintenancePersonnel) {
        selectedPersonnel = person
        name = person.name
        email = person.email
        phone = person.phone
        specialization = person.specialization
        selectedCertifications = person.certifications
        selectedSkills = person.skills
        isShowingEditPersonnel = true
    }
    
    func resetForm() {
        name = ""
        email = ""
        phone = ""
        specialization = ""
        selectedCertifications = []
        selectedSkills = []
        isShowingAddPersonnel = false
    }
    
    // Certification management methods
    func addSelectedCertification() {
        let certification = Certification(
            name: certificationFormData.name,
            issuer: certificationFormData.issuer,
            dateObtained: certificationFormData.dateObtained,
            expirationDate: certificationFormData.expirationDate,
            category: certificationFormData.category
        )
        selectedCertifications.append(certification)
        certificationFormData = CertificationFormData()
        isAddingCertification = false
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
        var dateObtained: Date = Date()
        var expirationDate: Date? = nil
        var hasExpirationDate: Bool = false
        var category: Certification.CertificationCategory = .technician
    }
} 