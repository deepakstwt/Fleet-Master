import Foundation
import Supabase

/// Manager class for all Driver-related Supabase operations
final class DriverSupabaseManager {
    static let shared = DriverSupabaseManager()
    
    private let supabase = SupabaseManager.shared.supabase
    
    private init() {}
    
    // MARK: - Driver CRUD Operations
    func fetchAllDrivers() async throws -> [Driver] {
        do {
            let response = try await supabase
                .from("drivers")
                .select()
                .execute()
            
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            
            return drivers
            
        } catch let error as PostgrestError {
            print("Postgrest error fetching drivers: \(error)")
            print("Error details: \(error.localizedDescription)")
            throw error
        } catch let error as DecodingError {
            print("Decoding error fetching drivers: \(error)")
            switch error {
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type), context: \(context.debugDescription), codingPath: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("Value not found: expected \(type), context: \(context.debugDescription), codingPath: \(context.codingPath)")
            case .keyNotFound(let key, let context):
                print("Key not found: \(key.stringValue), context: \(context.debugDescription), codingPath: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription), codingPath: \(context.codingPath)")
            @unknown default:
                print("Unknown decoding error: \(error)")
            }
            throw error
        } catch {
            print("Error fetching drivers: \(error)")
            print("Error type: \(type(of: error))")
            print("Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch drivers with optional filtering
    /// - Parameters:
    ///   - isActive: Optional filter for driver active status
    ///   - isAvailable: Optional filter for driver availability
    /// - Returns: Array of filtered Driver objects
    /// - Throws: Database errors
    func fetchDrivers(isActive: Bool? = nil, isAvailable: Bool? = nil) async throws -> [Driver] {
        do {
            var query = supabase.from("drivers").select()
            
            if let isActive = isActive {
                query = query.eq("is_active", value: isActive)
            }
            
            if let isAvailable = isAvailable {
                query = query.eq("is_available", value: isAvailable)
            }
            
            let response = try await query.execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            return drivers
        } catch {
            print("Error fetching filtered drivers: \(error)")
            throw error
        }
    }
    
    /// Add a new driver to the database
    /// - Parameter driver: Driver object to add
    /// - Returns: Added Driver object with server-generated ID
    /// - Throws: Database errors
    func addDriver(_ driver: Driver) async throws -> Driver {
        do {
            // Struct for inserting driver data without password field
            struct DriverInsert: Encodable {
                let id: String
                let name: String
                let email: String
                let phone: String
                let license_number: String
                let hire_date: Date
                let is_active: Bool
                let is_available: Bool
                let vehicle_categories: [String]
                
                // CodingKeys to match database column names
                enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case email
                    case phone
                    case license_number
                    case hire_date
                    case is_active
                    case is_available
                    case vehicle_categories
                }
            }
            
            // 1. First create a user in the auth.users table via Supabase Auth API
            print("Creating user in auth.users table...")
            let authUser = try await supabase.auth.signUp(
                email: driver.email,
                password: driver.password,
                data: [
                    "name": .string(driver.name),
                    "role": .string("driver")
                ]
            )
            
            // 2. Get the user's UUID to use for the driver record
            let userId = authUser.user.id.uuidString
            print("Got user ID: \(userId)")
            
            // 3. Create a driver insert object with the auth user's UUID but without password
            let driverInsert = DriverInsert(
                id: userId,
                name: driver.name,
                email: driver.email,
                phone: driver.phone,
                license_number: driver.licenseNumber,
                hire_date: driver.hireDate,
                is_active: driver.isActive,
                is_available: driver.isAvailable,
                vehicle_categories: driver.vehicleCategories
            )
            
            // 4. Insert the driver record into the drivers table
            print("Inserting driver into drivers table...")
            let response = try await supabase
                .from("drivers")
                .insert(driverInsert)
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
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let drivers = try decoder.decode([Driver].self, from: jsonData)
                print("Successfully decoded \(drivers.count) drivers")
                
                guard let newDriver = drivers.first else {
                    throw NSError(domain: "DriverSupabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get inserted driver: No drivers returned"])
                }
                
                return newDriver
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
            print("Error adding driver: \(error.localizedDescription)")
            print("Error type: \(type(of: error))")
            throw error
        }
    }
    
    /// Update an existing driver in the database
    /// - Parameter driver: Driver object with updated values
    /// - Returns: Updated Driver object
    /// - Throws: Database errors
    func updateDriver(_ driver: Driver) async throws -> Driver {
        do {
            // Create update dictionary without password
            struct DriverUpdate: Encodable {
                let id: String
                let name: String
                let email: String
                let phone: String
                let license_number: String
                let hire_date: Date
                let is_active: Bool
                let is_available: Bool
                let vehicle_categories: [String]
                
                // CodingKeys to match database column names
                enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case email
                    case phone
                    case license_number
                    case hire_date
                    case is_active
                    case is_available
                    case vehicle_categories
                }
            }
            
            let driverUpdate = DriverUpdate(
                id: driver.id,
                name: driver.name,
                email: driver.email,
                phone: driver.phone,
                license_number: driver.licenseNumber,
                hire_date: driver.hireDate,
                is_active: driver.isActive,
                is_available: driver.isAvailable,
                vehicle_categories: driver.vehicleCategories
            )
            
            let response = try await supabase
                .from("drivers")
                .update(driverUpdate)
                .eq("id", value: driver.id)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            
            guard let updatedDriver = drivers.first else {
                throw NSError(domain: "DriverSupabaseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated driver"])
            }
            
            return updatedDriver
        } catch {
            print("Error updating driver: \(error)")
            throw error
        }
    }
    
    /// Update just the active status of a driver
    /// - Parameters:
    ///   - driverId: ID of the driver to update
    ///   - isActive: New active status
    /// - Returns: Updated Driver object
    /// - Throws: Database errors
    func toggleDriverStatus(driverId: String, isActive: Bool) async throws -> Driver {
        do {
            let response = try await supabase
                .from("drivers")
                .update(["is_active": isActive])
                .eq("id", value: driverId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            
            guard let updatedDriver = drivers.first else {
                throw NSError(domain: "DriverSupabaseManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get driver after status update"])
            }
            
            return updatedDriver
        } catch {
            print("Error toggling driver status: \(error)")
            throw error
        }
    }
    
    /// Update availability status of a driver
    /// - Parameters:
    ///   - driverId: ID of the driver to update
    ///   - isAvailable: New availability status
    /// - Returns: Updated Driver object
    /// - Throws: Database errors
    func toggleDriverAvailability(driverId: String, isAvailable: Bool) async throws -> Driver {
        do {
            let response = try await supabase
                .from("drivers")
                .update(["is_available": isAvailable])
                .eq("id", value: driverId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            
            guard let updatedDriver = drivers.first else {
                throw NSError(domain: "DriverSupabaseManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to get driver after availability update"])
            }
            
            return updatedDriver
        } catch {
            print("Error toggling driver availability: \(error)")
            throw error
        }
    }
    
    /// Delete a driver from the database
    /// - Parameter id: ID of the driver to delete
    /// - Throws: Database errors
    func deleteDriver(id: String) async throws {
        do {
            // 1. First delete the user from auth.users via Supabase Auth API
            try await supabase.auth.admin.deleteUser(id: id)
            
            // 2. Then delete the driver record from the drivers table
            try await supabase
                .from("drivers")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            print("Error deleting driver: \(error)")
            throw error
        }
    }
    
    /// Search drivers by text
    /// - Parameter searchText: Text to search for in driver fields
    /// - Returns: Array of matching Driver objects
    /// - Throws: Database errors
    func searchDrivers(searchText: String) async throws -> [Driver] {
        do {
            let searchLower = searchText.lowercased()
            
            let response = try await supabase
                .from("drivers")
                .select()
                .or("name.ilike.%\(searchLower)%,email.ilike.%\(searchLower)%,license_number.ilike.%\(searchLower)%,phone.ilike.%\(searchLower)%")
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let drivers = try decoder.decode([Driver].self, from: jsonData)
            return drivers
        } catch {
            print("Error searching drivers: \(error)")
            throw error
        }
    }
} 
