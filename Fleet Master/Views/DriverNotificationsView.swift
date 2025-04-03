import SwiftUI

struct DriverNotificationsView: View {
    @State private var notifications: [DriverNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    let driverId: String
    
    init(driverId: String) {
        self.driverId = driverId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Notifications")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button(action: loadNotifications) {
                            Text("Try Again")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else if notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You don't have any notifications at this time.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(notifications) { notification in
                            NotificationCell(notification: notification)
                                .onTapGesture {
                                    markAsRead(notification: notification)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await refreshNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshNotifications()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadNotifications()
            }
        }
    }
    
    private func loadNotifications() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedNotifications = try await DriverNotificationSupabaseManager.shared
                    .fetchNotificationsForDriver(driverId: driverId)
                
                await MainActor.run {
                    self.notifications = fetchedNotifications
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshNotifications() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedNotifications = try await DriverNotificationSupabaseManager.shared
                .fetchNotificationsForDriver(driverId: driverId)
            
            await MainActor.run {
                self.notifications = fetchedNotifications
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func markAsRead(notification: DriverNotification) {
        // Only mark as read if it's currently unread
        if notification.status == "unread" {
            Task {
                do {
                    let updatedNotification = try await DriverNotificationSupabaseManager.shared
                        .markNotificationAsRead(notificationId: notification.id)
                    
                    await MainActor.run {
                        // Update the notification in the array
                        if let index = notifications.firstIndex(where: { $0.id == updatedNotification.id }) {
                            notifications[index] = updatedNotification
                        }
                    }
                } catch {
                    print("Error marking notification as read: \(error)")
                }
            }
        }
    }
}

struct NotificationCell: View {
    let notification: DriverNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(notification.title)
                    .font(.headline)
                
                Spacer()
                
                if notification.status == "unread" {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            
            Text(notification.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Text(notification.notificationType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(typeColor.opacity(0.2))
                    .foregroundColor(typeColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(notification.status == "read" ? 0.7 : 1.0)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: notification.createdAt)
    }
    
    private var typeColor: Color {
        switch notification.notificationType {
        case "trip_assigned":
            return .green
        case "trip_updated":
            return .orange
        default:
            return .blue
        }
    }
}

#Preview {
    let sampleNotification = DriverNotification(
        id: "1", 
        driverId: "driver-1",
        title: "New Trip Assigned",
        message: "You have been assigned a new trip: Downtown Delivery from Warehouse to Office",
        notificationType: "trip_assigned",
        status: "unread",
        createdAt: Date()
    )
    
    return NotificationCell(notification: sampleNotification)
} 