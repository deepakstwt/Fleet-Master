import Foundation
import SwiftUI
import Combine

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [FleetNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let notificationManager = FleetNotificationSupabaseManager.shared
    private let localNotificationManager = NotificationManager.shared
    private var timer: Timer?
    private let pollingInterval: TimeInterval = 5.0 // 5 seconds
    private var lastKnownNotificationIds = Set<String>()
    
    init() {
        startPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    func startPolling() {
        // Initial fetch
        fetchNotifications()
        
        // Set up timer for periodic polling
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.fetchNotifications()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchNotifications() {
        Task {
            await fetchNotificationsAsync()
        }
    }
    
    @MainActor
    private func fetchNotificationsAsync() async {
        // Don't show loading indicator for background refreshes
        let wasEmpty = notifications.isEmpty
        if wasEmpty {
            isLoading = true
        }
        
        do {
            let fetchedNotifications = try await notificationManager.fetchNotifications()
            
            // Check for new notifications
            if !notifications.isEmpty {
                checkForNewNotifications(currentNotifications: notifications, newNotifications: fetchedNotifications)
            } else {
                // If this is the first load, just store the IDs without showing notifications
                lastKnownNotificationIds = Set(fetchedNotifications.map { $0.id })
            }
            
            // Update the UI
            self.notifications = fetchedNotifications
            self.unreadCount = fetchedNotifications.filter { $0.status == "unread" }.count
            
            if wasEmpty {
                self.isLoading = false
            }
            self.errorMessage = nil
        } catch {
            if wasEmpty {
                self.isLoading = false
            }
            self.errorMessage = "Error fetching notifications: \(error.localizedDescription)"
            print("Error fetching notifications: \(error)")
        }
    }
    
    private func checkForNewNotifications(currentNotifications: [FleetNotification], newNotifications: [FleetNotification]) {
        // Get set of current notification IDs
        let currentIds = Set(currentNotifications.map { $0.id })
        
        // Find notifications that weren't in our previous set and are unread
        let newUnreadNotifications = newNotifications
            .filter { $0.status == "unread" && !currentIds.contains($0.id) && !lastKnownNotificationIds.contains($0.id) }
        
        // Update lastKnownNotificationIds with all current IDs
        lastKnownNotificationIds = Set(newNotifications.map { $0.id })
        
        // Send push notifications for new unread notifications
        for notification in newUnreadNotifications {
            showPushNotification(for: notification)
        }
    }
    
    private func showPushNotification(for notification: FleetNotification) {
        // Use the NotificationManager to show push notifications
        localNotificationManager.sendFleetNotification(notification: notification)
    }
    
    func markAsRead(notification: FleetNotification) {
        guard notification.status == "unread" else { return }
        
        Task {
            do {
                let updatedNotification = try await notificationManager.markNotificationAsRead(
                    notificationId: notification.id
                )
                
                await MainActor.run {
                    // Update the notification in the array
                    if let index = notifications.firstIndex(where: { $0.id == updatedNotification.id }) {
                        notifications[index] = updatedNotification
                    }
                    
                    // Update unread count
                    self.unreadCount = self.notifications.filter { $0.status == "unread" }.count
                }
            } catch {
                print("Error marking notification as read: \(error)")
            }
        }
    }
    
    func markAllAsRead() {
        let unreadNotifications = notifications.filter { $0.status == "unread" }
        
        for notification in unreadNotifications {
            Task {
                do {
                    let _ = try await notificationManager.markNotificationAsRead(
                        notificationId: notification.id
                    )
                } catch {
                    print("Error marking notification \(notification.id) as read: \(error)")
                }
            }
        }
        
        // Optimistically update the UI immediately
        DispatchQueue.main.async {
            for index in self.notifications.indices {
                if self.notifications[index].status == "unread" {
                    self.notifications[index].status = "read"
                }
            }
            self.unreadCount = 0
        }
    }
} 