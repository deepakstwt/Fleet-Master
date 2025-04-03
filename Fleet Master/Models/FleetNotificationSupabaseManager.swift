import Foundation
import Supabase

/// Manager class for all Fleet Notification-related Supabase operations
final class FleetNotificationSupabaseManager {
    /// Shared instance (singleton)
    static let shared = FleetNotificationSupabaseManager()
    
    /// Supabase client instance from SupabaseManager
    private let supabase = SupabaseManager.shared.supabase
    
    /// Private initializer for singleton
    private init() {}
    
    /// Fetch all notifications from the fleet_notifications table
    /// - Returns: Array of FleetNotification objects
    /// - Throws: Database errors
    func fetchNotifications() async throws -> [FleetNotification] {
        do {
            let response = try await supabase
                .from("fleet_notifications")
                .select()
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([FleetNotification].self, from: response.data)
            
            return notifications
        } catch {
            print("Error fetching fleet notifications: \(error)")
            throw error
        }
    }
    
    /// Mark a notification as read
    /// - Parameter notificationId: The UUID of the notification
    /// - Returns: The updated notification
    /// - Throws: Database errors
    func markNotificationAsRead(notificationId: String) async throws -> FleetNotification {
        do {
            let response = try await supabase
                .from("fleet_notifications")
                .update(["status": "read"])
                .eq("id", value: notificationId)
                .select()
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([FleetNotification].self, from: response.data)
            
            guard let updatedNotification = notifications.first else {
                throw NSError(domain: "FleetNotificationSupabaseManager", code: 2, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to get updated notification"])
            }
            
            return updatedNotification
        } catch {
            print("Error marking notification as read: \(error)")
            throw error
        }
    }
    
    /// Add a new notification to the fleet_notifications table
    /// - Parameters:
    ///   - driverId: The UUID of the driver (optional)
    ///   - title: Title of the notification
    ///   - message: Message content of the notification
    ///   - notificationType: Type of notification
    ///   - status: Status of the notification (typically "unread" when created)
    /// - Returns: The created notification
    /// - Throws: Database errors
    func addNotification(
        driverId: String? = nil,
        title: String,
        message: String,
        notificationType: String,
        status: String = "unread"
    ) async throws -> FleetNotification {
        do {
            // Create the notification object
            let notification = FleetNotification(
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
                .from("fleet_notifications")
                .insert(notification)
                .select()
                .execute()
            
            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([FleetNotification].self, from: response.data)
            
            guard let createdNotification = notifications.first else {
                throw NSError(domain: "FleetNotificationSupabaseManager", code: 1, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to get created notification"])
            }
            
            return createdNotification
        } catch {
            print("Error adding fleet notification: \(error)")
            throw error
        }
    }
}

/// Model for fleet notifications
struct FleetNotification: Identifiable, Codable {
    var id: String
    var driverId: String?
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