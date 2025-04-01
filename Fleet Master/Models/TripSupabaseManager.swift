import Foundation
import Supabase

/// Manager class for all Trip-related Supabase operations
final class TripSupabaseManager {
    /// Shared instance (singleton)
    static let shared = TripSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    private let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    // MARK: - Connection Verification
    
    /// Verify that the Supabase connection is working properly
    /// - Returns: True if connection is valid, false otherwise
    /// - Throws: Database errors with detailed messages
    func verifyConnection() async throws -> Bool {
        do {
            // Simple ping to the database
            let response = try await supabase
                .from("trip")
                .select("id")
                .limit(1)
                .execute()
            
            // If we got here, connection is working
            return true
        } catch let error as PostgrestError {
            // Enhance error with more details
            let enhancedError = NSError(
                domain: "TripSupabaseManager",
                code: Int(error.code ?? "999") ?? 9999,
                userInfo: [
                    NSLocalizedDescriptionKey: "Supabase connection failed: \(error.message)",
                    "supabase_error": error.message,
                    "supabase_code": error.code ?? "unknown"
                ]
            )
            throw enhancedError
        } catch {
            // Re-throw with more context
            let connectionError = NSError(
                domain: "TripSupabaseManager",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to connect to Supabase: \(error.localizedDescription)"
                ]
            )
            throw connectionError
        }
    }
    
    // MARK: - Test Connection
    
    /// Test function to verify Supabase connection and database permissions
    func testConnection() async -> String {
        do {
            print("===== TESTING SUPABASE CONNECTION =====")
            // First, test basic connection
            let connectionTest = try await supabase.database
                .from("_test_connection")
                .select("*")
                .limit(1)
                .execute()
            
            print("Basic connection test completed with status: \(connectionTest.status)")
            
            // Now test trip table access
            print("Testing trip table access...")
            let tripAccessTest = try await supabase.database
                .from("trip")
                .select("id")
                .limit(1)
                .execute()
            
            print("Trip table SELECT access verified with status: \(tripAccessTest.status)")
            
            // Test trip table insert permission with a minimal dummy record
            // that we'll immediately delete if successful
            print("Testing trip table INSERT permission...")
            
            // Create minimal test trip with required fields only
            let testTrip = Trip(
                id: "test-\(UUID().uuidString)",
                title: "Test Trip",
                startLocation: "Test Start",
                endLocation: "Test End",
                scheduledStartTime: Date(),
                scheduledEndTime: Date().addingTimeInterval(3600),
                description: "Test Description"
            )
            
            // Try to insert
            let insertTest = try await supabase.database
                .from("trip")
                .insert(testTrip)
                .select()
                .execute()
            
            print("Trip table INSERT permission verified with status: \(insertTest.status)")
            
            // Handle the data - removing the optional binding since it's not optional
            let jsonString = String(data: insertTest.data, encoding: .utf8) ?? "No data"
            print("Response data string: \(jsonString)")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let insertedTrips = try decoder.decode([Trip].self, from: insertTest.data)
                if let insertedTestTrip = insertedTrips.first {
                    print("Inserted test trip successfully with ID: \(insertedTestTrip.id)")
                
                    // Now clean up by deleting the test trip
                    print("Cleaning up test data...")
                    try await supabase.database
                        .from("trip")
                        .delete()
                        .eq("id", value: insertedTestTrip.id)
                        .execute()
                
                    print("Test trip deleted successfully")
                }
            } catch {
                print("Failed to decode inserted trip: \(error)")
            }
            
            return "Connection and permissions verified successfully"
        } catch let error as PostgrestError {
            print("PostgrestError during connection test:")
            print("Code: \(error.code)")
            print("Message: \(error.message)")
            // PostgrestError doesn't have 'details' property so we remove it
            return "Error testing connection: \(error.message)"
        } catch {
            print("Unknown error during connection test: \(error.localizedDescription)")
            return "Error testing connection: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Trip CRUD Operations
    
    /// Fetch all trips from the database
    /// - Returns: Array of Trip objects
    /// - Throws: Database errors
    func fetchAllTrips() async throws -> [Trip] {
        do {
            print("Fetching trips from Supabase...")
            
            // Perform the query and decode in one step
            let response = try await supabase
                .from("trip")
                .select()
                .execute()
            
            print("Raw Supabase response: \(response)")
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            print("JSON data: \(String(data: jsonData, encoding: .utf8) ?? "Unable to convert to string")")
            
            // Decode the JSON data into Trip objects
            let decoder = JSONDecoder()
            // Configure the decoder to handle ISO dates
            decoder.dateDecodingStrategy = .iso8601
            
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            print("Successfully decoded \(trips.count) trips")
            return trips
        } catch let error as PostgrestError {
            print("Postgrest error fetching trips: \(error)")
            print("Error details: \(error.localizedDescription)")
            throw error
        } catch let error as DecodingError {
            print("Decoding error fetching trips: \(error)")
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
            print("Error fetching trips: \(error)")
            print("Error type: \(type(of: error))")
            print("Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch trips with optional filtering
    /// - Parameters:
    ///   - status: Optional filter for trip status
    ///   - driverId: Optional filter for driver ID
    ///   - vehicleId: Optional filter for vehicle ID
    /// - Returns: Array of filtered Trip objects
    /// - Throws: Database errors
    func fetchTrips(status: TripStatus? = nil, driverId: String? = nil, vehicleId: String? = nil) async throws -> [Trip] {
        do {
            var query = supabase.from("trip").select()
            
            if let status = status {
                query = query.eq("status", value: status.rawValue)
            }
            
            if let driverId = driverId {
                query = query.eq("driver_id", value: driverId)
            }
            
            if let vehicleId = vehicleId {
                query = query.eq("vehicleId", value: vehicleId)
            }
            
            let response = try await query.execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            return trips
        } catch {
            print("Error fetching filtered trips: \(error)")
            throw error
        }
    }
    
    /// Add a new trip to the database
    /// - Parameter trip: Trip object to add
    /// - Returns: Added Trip object with server-generated ID
    /// - Throws: Database errors
    func addTrip(_ trip: Trip) async throws -> Trip {
        do {
            // Debug logging
            print("===== TRIP ADD OPERATION START =====")
            print("Attempting to add trip to Supabase with ID: \(trip.id)")
            print("Trip details: \(trip)")
            
            // Encode trip to JSON to verify data format
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let jsonData = try? encoder.encode(trip),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Trip JSON being sent to Supabase: \(jsonString)")
            }
            
            let response = try await supabase
                .from("trip")
                .insert(trip)
                .select()
                .execute()
            
            // Debug response
            print("Supabase response received")
            print("Response status: \(response.status)")
            
            // Direct access since data is not optional
            let jsonString = String(data: response.data, encoding: .utf8) ?? "Unable to convert to string"
            print("Response data: \(jsonString)")
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            guard let newTrip = trips.first else {
                print("Failed to get inserted trip: No trips returned in response")
                throw NSError(domain: "TripSupabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get inserted trip"])
            }
            
            print("Trip successfully added with server ID: \(newTrip.id)")
            print("===== TRIP ADD OPERATION END =====")
            
            return newTrip
        } catch let error as PostgrestError {
            print("===== SUPABASE POSTGREST ERROR =====")
            print("Error code: \(error.code)")
            print("Error message: \(error.message)")
            // PostgrestError doesn't have a 'details' property
            print("===================================")
            throw error
        } catch {
            print("===== TRIP ADD OPERATION ERROR =====")
            print("Error type: \(type(of: error))")
            print("Error description: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key), context: \(context)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type), context: \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            print("===================================")
            throw error
        }
    }
    
    /// Update an existing trip in the database
    /// - Parameter trip: Trip object with updated values
    /// - Returns: Updated Trip object
    /// - Throws: Database errors
    func updateTrip(_ trip: Trip) async throws -> Trip {
        // Verify connection first
        try await verifyConnection()
        
        do {
            let response = try await supabase
                .from("trip")
                .update(trip)
                .eq("id", value: trip.id)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Print response for debugging
            print("Update trip response: \(String(data: jsonData, encoding: .utf8) ?? "unable to convert to string")")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            guard let updatedTrip = trips.first else {
                throw NSError(domain: "TripSupabaseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated trip"])
            }
            
            return updatedTrip
        } catch let error as PostgrestError {
            print("===== TRIP UPDATE ERROR =====")
            print("PostgrestError updating trip:")
            print("Error code: \(error.code)")
            print("Error message: \(error.message)")
            print("===================================")
            throw error
        } catch let error as DecodingError {
            print("===== TRIP UPDATE DECODING ERROR =====")
            switch error {
            case .dataCorrupted(let context):
                print("Data corrupted: \(context)")
            case .keyNotFound(let key, let context):
                print("Key not found: \(key), context: \(context)")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type), context: \(context)")
            case .valueNotFound(let type, let context):
                print("Value not found: expected \(type), context: \(context)")
            @unknown default:
                print("Unknown decoding error")
            }
            print("===================================")
            throw error
        } catch {
            print("Unknown error updating trip: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Struct for status updates to ensure Encodable conformance
    private struct TripStatusUpdate: Encodable {
        let status: String
        let actualStartTime: String?
        let actualEndTime: String?
    }
    
    /// Update the status of a trip
    /// - Parameters:
    ///   - tripId: ID of the trip to update
    ///   - status: New status
    ///   - actualStartTime: Actual start time (for in-progress trips)
    ///   - actualEndTime: Actual end time (for completed trips)
    /// - Returns: Updated Trip object
    /// - Throws: Database errors
    func updateTripStatus(tripId: String, status: TripStatus, actualStartTime: Date? = nil, actualEndTime: Date? = nil) async throws -> Trip {
        // Verify connection first
        try await verifyConnection()
        
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Create a properly Encodable struct instead of [String: Any]
            let updateData = TripStatusUpdate(
                status: status.rawValue,
                actualStartTime: actualStartTime != nil ? formatter.string(from: actualStartTime!) : nil,
                actualEndTime: actualEndTime != nil ? formatter.string(from: actualEndTime!) : nil
            )
            
            // Print the update data for debugging
            print("Updating trip status: ID=\(tripId), Status=\(status.rawValue)")
            
            let response = try await supabase
                .from("trip")
                .update(updateData)
                .eq("id", value: tripId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            // Print the response for debugging
            print("Status update response: \(String(data: jsonData, encoding: .utf8) ?? "unable to convert to string")")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            guard let updatedTrip = trips.first else {
                throw NSError(domain: "TripSupabaseManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get trip after status update"])
            }
            
            return updatedTrip
        } catch let error as PostgrestError {
            print("===== TRIP STATUS UPDATE ERROR =====")
            print("PostgrestError updating trip status:")
            print("Error code: \(error.code)")
            print("Error message: \(error.message)")
            print("===================================")
            throw error
        } catch {
            print("Error updating trip status: \(error)")
            throw error
        }
    }
    
    /// Struct for driver and vehicle assignment to ensure Encodable conformance
    private struct DriverVehicleAssignment: Encodable {
        let driver_id: String
        let vehicleId: String
    }
    
    /// Assign a driver and vehicle to a trip
    /// - Parameters:
    ///   - tripId: ID of the trip to update
    ///   - driverId: ID of the driver to assign
    ///   - vehicleId: ID of the vehicle to assign
    /// - Returns: Updated Trip object
    /// - Throws: Database errors
    func assignDriverAndVehicle(tripId: String, driverId: String, vehicleId: String) async throws -> Trip {
        do {
            // Create a properly Encodable struct instead of [String: Any]
            let updateData = DriverVehicleAssignment(
                driver_id: driverId,
                vehicleId: vehicleId
            )
            
            let response = try await supabase
                .from("trip")
                .update(updateData)
                .eq("id", value: tripId)
                .select()
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            guard let updatedTrip = trips.first else {
                throw NSError(domain: "TripSupabaseManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get trip after driver assignment"])
            }
            
            return updatedTrip
        } catch {
            print("Error assigning driver to trip: \(error)")
            throw error
        }
    }
    
    /// Delete a trip from the database
    /// - Parameter id: ID of the trip to delete
    /// - Throws: Database errors
    func deleteTrip(id: String) async throws {
        do {
            try await supabase
                .from("trip")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            print("Error deleting trip: \(error)")
            throw error
        }
    }
    
    /// Search trips by text
    /// - Parameter searchText: Text to search for in trip fields
    /// - Returns: Array of matching Trip objects
    /// - Throws: Database errors
    func searchTrips(searchText: String) async throws -> [Trip] {
        do {
            let searchLower = searchText.lowercased()
            
            let response = try await supabase
                .from("trip")
                .select()
                .or("title.ilike.%\(searchLower)%,startLocation.ilike.%\(searchLower)%,endLocation.ilike.%\(searchLower)%,description.ilike.%\(searchLower)%")
                .execute()
            
            // Directly use the data since it's not optional
            let jsonData = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trips = try decoder.decode([Trip].self, from: jsonData)
            return trips
        } catch {
            print("Error searching trips: \(error)")
            throw error
        }
    }
} 