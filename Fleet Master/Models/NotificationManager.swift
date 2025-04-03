import Foundation
import UserNotifications
import CoreLocation

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    // Published properties to track notification settings
    @Published var isAuthorized = false
    @Published var notificationSettings: UNNotificationSettings?
    
    // Default configuration settings
    @Published var offRouteAlertEnabled = true
    @Published var delayAlertEnabled = true
    @Published var arrivalDepartureAlertEnabled = true
    @Published var geofenceAlertEnabled = true
    
    // Thresholds for triggering alerts
    @Published var offRouteThresholdMeters: Double = 500
    @Published var delayThresholdMinutes: Int = 10
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        requestAuthorization()
        checkNotificationSettings()
    }
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("Error requesting notification authorization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func checkNotificationSettings() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
            }
        }
    }
    
    // MARK: - Trip Notification Methods
    
    func sendOffRouteAlert(tripId: String, tripTitle: String, distanceOffRoute: Double) {
        guard offRouteAlertEnabled, isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "वाहन मार्ग से बाहर! / Vehicle Off Route!"
        content.body = "यात्रा '\(tripTitle)' मार्ग से लगभग \(Int(distanceOffRoute)) मीटर बाहर है। / Trip '\(tripTitle)' is ~\(Int(distanceOffRoute)) meters off route."
        content.sound = .default
        content.badge = 1
        
        // Use tripId as identifier to avoid duplicates for the same trip
        let identifier = "off-route-\(tripId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending off-route notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendDelayAlert(tripId: String, tripTitle: String, delayMinutes: Int) {
        guard delayAlertEnabled, isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "यात्रा में देरी! / Trip Delay!"
        content.body = "यात्रा '\(tripTitle)' अनुसूची से \(delayMinutes) मिनट पीछे है। / Trip '\(tripTitle)' is \(delayMinutes) minutes behind schedule."
        content.sound = .default
        content.badge = 1
        
        // Use tripId as identifier but allow multiple delay notifications with timestamp
        let identifier = "delay-\(tripId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending delay notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendArrivalAlert(tripId: String, tripTitle: String, location: String) {
        guard arrivalDepartureAlertEnabled, isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "वाहन पहुंच गया! / Vehicle Arrived!"
        content.body = "यात्रा '\(tripTitle)' अपने गंतव्य '\(location)' पर पहुंच गई है। / Trip '\(tripTitle)' has arrived at its destination '\(location)'."
        content.sound = .default
        content.badge = 1
        
        let identifier = "arrival-\(tripId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending arrival notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendDepartureAlert(tripId: String, tripTitle: String, location: String) {
        guard arrivalDepartureAlertEnabled, isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "वाहन निकल गया! / Vehicle Departed!"
        content.body = "यात्रा '\(tripTitle)' स्थान '\(location)' से शुरू हो गई है। / Trip '\(tripTitle)' has departed from '\(location)'."
        content.sound = .default
        content.badge = 1
        
        let identifier = "departure-\(tripId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending departure notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendGeofenceAlert(tripId: String, tripTitle: String, zoneName: String, eventType: GeofenceEventType) {
        guard geofenceAlertEnabled, isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        
        switch eventType {
        case .entry:
            content.title = "जियोफेंस प्रवेश / Geofence Entry"
            content.body = "यात्रा '\(tripTitle)' का वाहन '\(zoneName)' क्षेत्र में प्रवेश कर गया है। / Vehicle for trip '\(tripTitle)' has entered the '\(zoneName)' zone."
        case .exit:
            content.title = "जियोफेंस निकास / Geofence Exit"
            content.body = "यात्रा '\(tripTitle)' का वाहन '\(zoneName)' क्षेत्र से बाहर निकल गया है। / Vehicle for trip '\(tripTitle)' has exited the '\(zoneName)' zone."
        }
        
        content.sound = .default
        content.badge = 1
        
        let identifier = "geofence-\(tripId)-\(eventType.rawValue)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending geofence notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Badge Management
    
    func resetBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Error resetting badge count: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Schedule Local Notifications for Testing
    
    func scheduleTestNotification(seconds: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "टेस्ट नोटिफिकेशन / Test Notification"
        content.body = "यह एक परीक्षण अधिसूचना है। / This is a test notification."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling test notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fleet Notification Methods
    
    func sendFleetNotification(notification: FleetNotification) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = .default
        content.badge = 1
        
        // Add category and notification type as user info for handling taps
        content.userInfo = [
            "notificationType": notification.notificationType,
            "notificationId": notification.id,
            "driverId": notification.driverId as Any
        ]
        
        // Use fleetNotification ID in the identifier to avoid duplicates
        let identifier = "fleet-notification-\(notification.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending fleet notification: \(error.localizedDescription)")
            } else {
                print("Successfully scheduled fleet notification: \(notification.title)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // This method will be called when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // This method will be called when the user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the notification tap action here
        let identifier = response.notification.request.identifier
        
        // Parse the identifier to determine which trip/vehicle to focus on
        if identifier.starts(with: "off-route-"),
           let tripId = identifier.components(separatedBy: "-").dropFirst(2).first {
            // Navigate to the specific trip
            print("User tapped on off-route notification for tripId: \(tripId)")
            // In a real app, you would use an AppState or similar to navigate to the trip
        }
        
        // Handle fleet notifications
        if identifier.starts(with: "fleet-notification-") {
            let userInfo = response.notification.request.content.userInfo
            
            // Extract notification details from userInfo
            if let notificationId = userInfo["notificationId"] as? String,
               let notificationType = userInfo["notificationType"] as? String {
                print("User tapped on fleet notification: \(notificationId) of type: \(notificationType)")
                
                // Mark notification as read in database
                Task {
                    do {
                        let _ = try await FleetNotificationSupabaseManager.shared.markNotificationAsRead(
                            notificationId: notificationId
                        )
                        print("Successfully marked notification as read: \(notificationId)")
                    } catch {
                        print("Error marking notification as read: \(error)")
                    }
                }
                
                // Open notifications view or navigate to relevant screen based on notification type
                // This would be done via a NotificationCenter post or shared app state manager
                NotificationCenter.default.post(
                    name: NSNotification.Name("DidTapFleetNotification"),
                    object: nil,
                    userInfo: ["notificationId": notificationId, "notificationType": notificationType]
                )
            }
        }
        
        completionHandler()
    }
}

enum GeofenceEventType: String {
    case entry = "entry"
    case exit = "exit"
} 