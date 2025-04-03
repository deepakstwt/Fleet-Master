import Foundation
import Supabase

/// Manager class for all Driver Notification-related Supabase operations
final class DriverNotificationSupabaseManager {
    /// Shared instance (singleton)
    static let shared = DriverNotificationSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    private let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    /// Add a new notification for a driver
    /// - Parameters:
    ///   - driverId: The UUID of the driver
    ///   - title: Title of the notification
    ///   - message: Message content of the notification
    ///   - notificationType: Type of notification (e.g., "trip_assigned", "trip_updated")
    ///   - status: Status of the notification (typically "unread" when created)
    /// - Returns: The created notification
    /// - Throws: Database errors
    func addDriverNotification(
        driverId: String,
        title: String,
        message: String,
        notificationType: String,
        status: String = "unread"
    ) async throws -> DriverNotification {
        do {
            // Create the notification object
            let notification = DriverNotification(
                id: UUID().uuidString,
                driverId: driverId,
                title: title,
                message: message,
                notificationType: notificationType,
                status: status,
                createdAt: Date()
            )
            
            // Insert into database
            let response = try await supabase
                .from("driver_received_notifications")
                .insert(notification)
                .select()
                .execute()
            
            // Debug information
            print("Added driver notification with response status: \(response.status)")
            
            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([DriverNotification].self, from: response.data)
            
            guard let createdNotification = notifications.first else {
                throw NSError(domain: "DriverNotificationSupabaseManager", code: 1, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to get created notification"])
            }
            
            return createdNotification
        } catch {
            print("Error adding driver notification: \(error)")
            throw error
        }
    }
    
    /// Create trip assigned notification for a driver
    /// - Parameters:
    ///   - driverId: The UUID of the driver
    ///   - trip: The trip that was assigned
    /// - Returns: The created notification
    /// - Throws: Database errors
    func createTripAssignedNotification(driverId: String, trip: Trip) async throws -> DriverNotification {
        let title = "New Trip Assigned"
        let message = "You have been assigned a new trip: \(trip.title) from \(trip.startLocation) to \(trip.endLocation)"
        
        return try await addDriverNotification(
            driverId: driverId,
            title: title,
            message: message,
            notificationType: "trip_assigned"
        )
    }
    
    /// Create trip updated notification for a driver
    /// - Parameters:
    ///   - driverId: The UUID of the driver
    ///   - trip: The trip that was updated
    /// - Returns: The created notification
    /// - Throws: Database errors
    func createTripUpdatedNotification(driverId: String, trip: Trip) async throws -> DriverNotification {
        let title = "Trip Updated"
        let message = "A trip assigned to you has been updated: \(trip.title)"
        
        return try await addDriverNotification(
            driverId: driverId,
            title: title,
            message: message,
            notificationType: "trip_updated"
        )
    }
    
    /// Fetch all notifications for a specific driver
    /// - Parameter driverId: The UUID of the driver
    /// - Returns: Array of DriverNotification objects
    /// - Throws: Database errors
    func fetchNotificationsForDriver(driverId: String) async throws -> [DriverNotification] {
        do {
            let response = try await supabase
                .from("driver_received_notifications")
                .select()
                .eq("driver_id", value: driverId)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([DriverNotification].self, from: response.data)
            
            return notifications
        } catch {
            print("Error fetching driver notifications: \(error)")
            throw error
        }
    }
    
    /// Mark a notification as read
    /// - Parameter notificationId: The UUID of the notification
    /// - Returns: The updated notification
    /// - Throws: Database errors
    func markNotificationAsRead(notificationId: String) async throws -> DriverNotification {
        do {
            let response = try await supabase
                .from("driver_received_notifications")
                .update(["status": "read"])
                .eq("id", value: notificationId)
                .select()
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([DriverNotification].self, from: response.data)
            
            guard let updatedNotification = notifications.first else {
                throw NSError(domain: "DriverNotificationSupabaseManager", code: 2, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to get updated notification"])
            }
            
            return updatedNotification
        } catch {
            print("Error marking notification as read: \(error)")
            throw error
        }
    }
}

/// Model for driver notifications
struct DriverNotification: Identifiable, Codable {
    var id: String
    var driverId: String
    var title: String
    var message: String
    var notificationType: String
    var status: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case title
        case message
        case notificationType = "notification_type"
        case status
        case createdAt = "created_at"
    }
} 