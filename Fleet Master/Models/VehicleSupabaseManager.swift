import Foundation
import Supabase

/// Manager class for all Vehicle-related Supabase operations
final class VehicleSupabaseManager {
    /// Shared instance (singleton)
    static let shared = VehicleSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    private let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    // MARK: - Vehicle CRUD Operations
    
    /// Fetch all vehicles from the database
    /// - Returns: Array of Vehicle objects
    /// - Throws: Database errors
    func fetchAllVehicles() async throws -> [Vehicle] {
        do {
            print("Fetching vehicles from Supabase...")
            
            // Perform the query and decode in one step
            let response = try await supabase
                .from("vehicles")
                .select()
                .execute()
            
            print("Raw Supabase response: \(response)")
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            print("JSON data: \(String(describing: String(data: jsonData, encoding: .utf8)))")
            
            // Decode the JSON data into Vehicle objects
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            
            print("Successfully decoded \(vehicles.count) vehicles")
            return vehicles
        } catch let error as PostgrestError {
            print("Postgrest error fetching vehicles: \(error)")
            print("Error details: \(error.localizedDescription)")
            throw error
        } catch let error as DecodingError {
            print("Decoding error fetching vehicles: \(error)")
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
            print("Error fetching vehicles: \(error)")
            print("Error type: \(type(of: error))")
            print("Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch vehicles with optional filtering
    /// - Parameters:
    ///   - isActive: Optional filter for vehicle active status
    ///   - vehicleType: Optional filter for vehicle type
    /// - Returns: Array of filtered Vehicle objects
    /// - Throws: Database errors
    func fetchVehicles(isActive: Bool? = nil, vehicleType: VehicleType? = nil) async throws -> [Vehicle] {
        do {
            var query = supabase.from("vehicles").select()
            
            if let isActive = isActive {
                query = query.eq("is_active", value: isActive)
            }
            
            if let vehicleType = vehicleType {
                query = query.eq("vehicle_type", value: vehicleType.rawValue)
            }
            
            let response = try await query.execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            return vehicles
        } catch {
            print("Error fetching filtered vehicles: \(error)")
            throw error
        }
    }
    
    /// Add a new vehicle to the database
    /// - Parameter vehicle: Vehicle object to add
    /// - Returns: Added Vehicle object with server-generated ID
    /// - Throws: Database errors
    func addVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        do {
            let response = try await supabase
                .from("vehicles")
                .insert(vehicle)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            
            guard let newVehicle = vehicles.first else {
                throw NSError(domain: "VehicleSupabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get inserted vehicle"])
            }
            
            return newVehicle
        } catch {
            print("Error adding vehicle: \(error)")
            throw error
        }
    }
    
    /// Update an existing vehicle in the database
    /// - Parameter vehicle: Vehicle object with updated values
    /// - Returns: Updated Vehicle object
    /// - Throws: Database errors
    func updateVehicle(_ vehicle: Vehicle) async throws -> Vehicle {
        do {
            let response = try await supabase
                .from("vehicles")
                .update(vehicle)
                .eq("id", value: vehicle.id)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            
            guard let updatedVehicle = vehicles.first else {
                throw NSError(domain: "VehicleSupabaseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated vehicle"])
            }
            
            return updatedVehicle
        } catch {
            print("Error updating vehicle: \(error)")
            throw error
        }
    }
    
    /// Update just the active status of a vehicle
    /// - Parameters:
    ///   - vehicleId: ID of the vehicle to update
    ///   - isActive: New active status
    /// - Returns: Updated Vehicle object
    /// - Throws: Database errors
    func toggleVehicleStatus(vehicleId: String, isActive: Bool) async throws -> Vehicle {
        do {
            let response = try await supabase
                .from("vehicles")
                .update(["is_active": isActive])
                .eq("id", value: vehicleId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            
            guard let updatedVehicle = vehicles.first else {
                throw NSError(domain: "VehicleSupabaseManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get vehicle after status update"])
            }
            
            return updatedVehicle
        } catch {
            print("Error toggling vehicle status: \(error)")
            throw error
        }
    }
    
    /// Delete a vehicle from the database
    /// - Parameter id: ID of the vehicle to delete
    /// - Throws: Database errors
    func deleteVehicle(id: String) async throws {
        do {
            try await supabase
                .from("vehicles")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            print("Error deleting vehicle: \(error)")
            throw error
        }
    }
    
    /// Search vehicles by text
    /// - Parameter searchText: Text to search for in vehicle fields
    /// - Returns: Array of matching Vehicle objects
    /// - Throws: Database errors
    func searchVehicles(searchText: String) async throws -> [Vehicle] {
        do {
            let searchLower = searchText.lowercased()
            
            let response = try await supabase
                .from("vehicles")
                .select()
                .or("make.ilike.%\(searchLower)%,model.ilike.%\(searchLower)%,registration_number.ilike.%\(searchLower)%,vin.ilike.%\(searchLower)%")
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([Vehicle].self, from: jsonData)
            return vehicles
        } catch {
            print("Error searching vehicles: \(error)")
            throw error
        }
    }
} 