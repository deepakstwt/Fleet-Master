import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = viewModel.errorMessage {
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
                        
                        Button(action: viewModel.fetchNotifications) {
                            Text("Try Again")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else if viewModel.notifications.isEmpty {
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
                        ForEach(viewModel.notifications) { notification in
                            FleetNotificationCell(notification: notification)
                                .onTapGesture {
                                    viewModel.markAsRead(notification: notification)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        viewModel.fetchNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if viewModel.unreadCount > 0 {
                            Button(action: {
                                viewModel.markAllAsRead()
                            }) {
                                Text("Mark All Read")
                                    .font(.subheadline)
                            }
                        }
                        
                        Button(action: {
                            viewModel.fetchNotifications()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.fetchNotifications()
            }
        }
    }
}

struct FleetNotificationCell: View {
    let notification: FleetNotification
    
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
        case "trip_assigned", "trip_created":
            return .green
        case "trip_updated":
            return .orange
        case "alert", "warning":
            return .red
        default:
            return .blue
        }
    }
}

#Preview {
    let viewModel = NotificationsViewModel()
    return NotificationsView(viewModel: viewModel)
} 