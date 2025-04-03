import Foundation
import Supabase

/// Manager class for all Driver Maintenance Request-related Supabase operations
final class DriverMaintenanceSupabaseManager {
    /// Shared instance (singleton)
    static let shared = DriverMaintenanceSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    /// Fetch all driver maintenance requests from Supabase
    /// - Returns: Array of DriverMaintenanceRequest objects
    /// - Throws: Database errors
    func fetchAllDriverMaintenanceRequests() async throws -> [DriverMaintenanceRequest] {
        do {
            let response = try await supabase
                .from("Driver_Maintenance_Requests")
                .select()
                .order("created_at", ascending: false)
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let requests = try decoder.decode([DriverMaintenanceRequest].self, from: data)
            return requests
        } catch {
            print("Error fetching driver maintenance requests: \(error)")
            throw error
        }
    }
    
    /// Fetch driver maintenance requests by vehicle ID
    /// - Parameter vehicleId: ID of the vehicle
    /// - Returns: Array of DriverMaintenanceRequest objects for the given vehicle
    /// - Throws: Database errors
    func fetchDriverMaintenanceRequests(forVehicleId vehicleId: String) async throws -> [DriverMaintenanceRequest] {
        do {
            let response = try await supabase
                .from("Driver_Maintenance_Requests")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("created_at", ascending: false)
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let requests = try decoder.decode([DriverMaintenanceRequest].self, from: data)
            return requests
        } catch {
            print("Error fetching driver maintenance requests for vehicle: \(error)")
            throw error
        }
    }
    
    /// Fetch pending driver maintenance requests (not accepted yet)
    /// - Returns: Array of pending DriverMaintenanceRequest objects
    /// - Throws: Database errors
    func fetchPendingDriverMaintenanceRequests() async throws -> [DriverMaintenanceRequest] {
        do {
            let response = try await supabase
                .from("Driver_Maintenance_Requests")
                .select()
                .eq("accepted", value: false)
                .eq("completed", value: false)
                .order("created_at", ascending: false)
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let requests = try decoder.decode([DriverMaintenanceRequest].self, from: data)
            return requests
        } catch {
            print("Error fetching pending driver maintenance requests: \(error)")
            throw error
        }
    }
    
    /// Update the status of a driver maintenance request
    /// - Parameters:
    ///   - requestId: ID of the request to update
    ///   - accepted: New accepted status
    /// - Returns: Updated DriverMaintenanceRequest object
    /// - Throws: Database errors
    func updateDriverMaintenanceRequestStatus(requestId: String, accepted: Bool) async throws -> DriverMaintenanceRequest {
        do {
            let response = try await supabase
                .from("Driver_Maintenance_Requests")
                .update(["accepted": accepted])
                .eq("id", value: requestId)
                .select()
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let requests = try decoder.decode([DriverMaintenanceRequest].self, from: data)
            
            guard let updatedRequest = requests.first else {
                throw NSError(domain: "DriverMaintenanceSupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated request"])
            }
            
            return updatedRequest
        } catch {
            print("Error updating driver maintenance request status: \(error)")
            throw error
        }
    }
    
    /// Mark a driver maintenance request as completed
    /// - Parameter requestId: ID of the request to mark as completed
    /// - Throws: Database errors
    func markRequestCompleted(requestId: String) async throws {
        do {
            try await supabase
                .from("Driver_Maintenance_Requests")
                .update(["completed": true])
                .eq("id", value: requestId)
                .execute()
            
            try await supabase
                .from("Driver_Maintenance_Requests")
                .update(["status": "Completed"])
                .eq("id", value: requestId)
                .execute()
        } catch {
            print("Error marking driver maintenance request as completed: \(error)")
            throw error
        }
    }
} 