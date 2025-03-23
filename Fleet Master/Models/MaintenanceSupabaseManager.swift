import Foundation
import Supabase

/// Manager class for all Maintenance Personnel-related Supabase operations
final class MaintenanceSupabaseManager {
    /// Shared instance (singleton)
    static let shared = MaintenanceSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    // MARK: - Helper Methods
    
    /// Create a JSONDecoder with custom date decoding strategy that can handle multiple date formats
    private func createDecoder() -> JSONDecoder {
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
                    }(),
                    // Just date
                    { () -> DateFormatter in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
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
                // If it's not a string, try as a timestamp (number of seconds since 1970)
                do {
                    let timestamp = try container.decode(Double.self)
                    return Date(timeIntervalSince1970: timestamp)
                } catch {
                    throw DecodingError.dataCorruptedError(in: container, 
                                                          debugDescription: "Date format not recognized")
                }
            }
        }
        return decoder
    }
    
    // MARK: - Maintenance Personnel CRUD Operations
    
    /// Check if the maintenance_personnel table exists in Supabase
    /// - Returns: Boolean indicating if the table exists
    /// - Throws: Database errors
    func checkTableExists() async throws -> Bool {
        do {
            print("Checking if maintenance_personnel table exists...")
            
            // Instead of using custom RPC, we can try to query the table
            // If the table doesn't exist, it will throw an error
            let response = try await supabase
                .from("maintenance_personnel")
                .select("id")
                .limit(0)
                .execute()
            
            print("Table check response: \(response)")
            
            // If we got here, the table exists
            print("maintenance_personnel table exists")
            return true
        } catch {
            print("Error checking if table exists: \(error)")
            
            // Check if the error message indicates a missing table
            if error.localizedDescription.contains("relation") && 
               error.localizedDescription.contains("does not exist") {
                print("maintenance_personnel table does not exist")
                return false
            }
            
            // For other errors, rethrow
            throw error
        }
    }
    
    /// Fetch all maintenance personnel from the database
    /// - Returns: Array of MaintenancePersonnel objects
    /// - Throws: Database errors
    func fetchAllPersonnel() async throws -> [MaintenancePersonnel] {
        do {
            print("Fetching maintenance personnel from Supabase...")
            
            // Try to query the table directly - if it doesn't exist, it will throw an error
            // that we can catch and provide a better message for
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .execute()
            
            print("Raw Supabase response: \(response)")
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            print("JSON data length: \(jsonData.count) bytes")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Raw JSON data from Supabase: \(jsonString)")
            }
            
            // Use our custom decoder that handles multiple date formats
            let decoder = createDecoder()
            
            do {
                let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
                print("Successfully decoded \(personnel.count) maintenance personnel")
                return personnel
            } catch let decodingError as DecodingError {
                print("JSON decoding error with custom decoder: \(decodingError)")
                
                // Detailed error reporting
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context)")
                    print("Coding path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type), context: \(context)")
                    print("Coding path: \(context.codingPath.map { $0.stringValue })")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), context: \(context)")
                    print("Coding path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                    print("Coding path: \(context.codingPath.map { $0.stringValue })")
                @unknown default:
                    print("Unknown decoding error")
                }
                
                throw decodingError
            }
        } catch let error as PostgrestError {
            print("Postgrest error fetching maintenance personnel: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Check for specific error messages that indicate the table doesn't exist
            if error.localizedDescription.contains("relation") && 
               error.localizedDescription.contains("does not exist") {
                throw NSError(
                    domain: "MaintenanceSupabaseManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "The maintenance_personnel table does not exist in Supabase. Please run the SQL setup script from SUPABASE_SETUP.md."]
                )
            }
            
            throw error
        } catch {
            print("Error fetching maintenance personnel: \(error)")
            throw error
        }
    }
    
    /// Fetch maintenance personnel with filters
    /// - Parameter isActive: Optional filter for active status
    /// - Returns: Array of filtered MaintenancePersonnel objects
    /// - Throws: Database errors
    func fetchPersonnel(isActive: Bool? = nil) async throws -> [MaintenancePersonnel] {
        do {
            var query = supabase.from("maintenance_personnel").select()
            
            if let isActive = isActive {
                query = query.eq("is_active", value: isActive)
            }
            
            let response = try await query.execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Use our custom decoder that handles multiple date formats
            let decoder = createDecoder()
            let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
            return personnel
        } catch {
            print("Error fetching filtered maintenance personnel: \(error)")
            throw error
        }
    }
    
    /// Add a new maintenance personnel to the database
    /// - Parameter person: MaintenancePersonnel object to add
    /// - Returns: Added MaintenancePersonnel object with server-generated ID
    /// - Throws: Database errors
    func addPersonnel(_ person: MaintenancePersonnel) async throws -> MaintenancePersonnel {
        do {
            // Struct for inserting maintenance personnel data without password field
            struct PersonnelInsert: Encodable {
                let id: String
                let name: String
                let email: String
                let phone: String
                let hire_date: Date
                let is_active: Bool
                let certifications: [Certification]
                let skills: [Skill]
                
                // CodingKeys to match database column names
                enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case email
                    case phone
                    case hire_date
                    case is_active
                    case certifications
                    case skills
                }
            }
            
            // 1. First create a user in the auth.users table via Supabase Auth API
            print("Creating user in auth.users table...")
            let authUser = try await supabase.auth.signUp(
                email: person.email,
                password: person.password,
                data: [
                    "name": .string(person.name),
                    "role": .string("maintenance")
                ]
            )
            
            // 2. Get the user's UUID to use for the maintenance personnel record
            let userId = authUser.user.id.uuidString
            print("Got user ID: \(userId)")
            
            // 3. Create a personnel insert object with the auth user's UUID but without password
            let personnelInsert = PersonnelInsert(
                id: userId,
                name: person.name,
                email: person.email,
                phone: person.phone,
                hire_date: person.hireDate,
                is_active: person.isActive,
                certifications: person.certifications,
                skills: person.skills
            )
            
            // 4. Insert the maintenance personnel record into the maintenance_personnel table
            print("Inserting maintenance personnel into maintenance_personnel table...")
            let response = try await supabase
                .from("maintenance_personnel")
                .insert(personnelInsert)
                .select()
                .execute()
            
            // Print response for debugging
            print("Supabase insert response: \(response)")
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            print("JSON data length: \(jsonData.count) bytes")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON data content: \(jsonString)")
            }
            
            // Use our custom decoder
            let decoder = createDecoder()
            
            do {
                let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
                print("Successfully decoded \(personnel.count) maintenance personnel")
                
                guard let newPerson = personnel.first else {
                    throw NSError(domain: "MaintenanceSupabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get inserted maintenance personnel: No personnel returned"])
                }
                
                return newPerson
            } catch let decodingError as DecodingError {
                print("Decoding error: \(decodingError)")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type), context: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
                throw decodingError
            }
        } catch {
            print("Error adding maintenance personnel: \(error)")
            throw error
        }
    }
    
    /// Update an existing maintenance personnel in the database
    /// - Parameter person: MaintenancePersonnel object with updated values
    /// - Returns: Updated MaintenancePersonnel object
    /// - Throws: Database errors
    func updatePersonnel(_ person: MaintenancePersonnel) async throws -> MaintenancePersonnel {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let response = try await supabase
                .from("maintenance_personnel")
                .update(person)
                .eq("id", value: person.id)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Use our custom decoder
            let decoder = createDecoder()
            let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
            
            guard let updatedPerson = personnel.first else {
                throw NSError(domain: "MaintenanceSupabaseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated maintenance personnel"])
            }
            
            return updatedPerson
        } catch {
            print("Error updating maintenance personnel: \(error)")
            throw error
        }
    }
    
    /// Update just the active status of a maintenance personnel
    /// - Parameters:
    ///   - personId: ID of the maintenance personnel to update
    ///   - isActive: New active status
    /// - Returns: Updated MaintenancePersonnel object
    /// - Throws: Database errors
    func togglePersonnelStatus(personId: String, isActive: Bool) async throws -> MaintenancePersonnel {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .update(["is_active": isActive])
                .eq("id", value: personId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Use our custom decoder
            let decoder = createDecoder()
            let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
            
            guard let updatedPerson = personnel.first else {
                throw NSError(domain: "MaintenanceSupabaseManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get maintenance personnel after status update"])
            }
            
            return updatedPerson
        } catch {
            print("Error toggling maintenance personnel status: \(error)")
            throw error
        }
    }
    
    /// Delete a maintenance personnel from the database
    /// - Parameter id: ID of the maintenance personnel to delete
    /// - Throws: Database errors
    func deletePersonnel(id: String) async throws {
        do {
            // 1. First delete the user from auth.users table via Supabase Auth Admin API
            print("Deleting user from auth.users table...")
            try await supabase.auth.admin.deleteUser(id: id)
            
            // 2. Then delete the personnel record from the maintenance_personnel table
            print("Deleting personnel from maintenance_personnel table...")
            try await supabase
                .from("maintenance_personnel")
                .delete()
                .eq("id", value: id)
                .execute()
            
            print("Successfully deleted maintenance personnel with ID: \(id)")
        } catch {
            print("Error deleting maintenance personnel: \(error)")
            throw error
        }
    }
    
    /// Search maintenance personnel by text
    /// - Parameter searchText: Text to search for in maintenance personnel fields
    /// - Returns: Array of matching MaintenancePersonnel objects
    /// - Throws: Database errors
    func searchPersonnel(searchText: String) async throws -> [MaintenancePersonnel] {
        do {
            let searchLower = searchText.lowercased()
            
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .or("name.ilike.%\(searchLower)%,email.ilike.%\(searchLower)%,phone.ilike.%\(searchLower)%")
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Use our custom decoder
            let decoder = createDecoder()
            let personnel = try decoder.decode([MaintenancePersonnel].self, from: jsonData)
            return personnel
        } catch {
            print("Error searching maintenance personnel: \(error)")
            throw error
        }
    }
} 