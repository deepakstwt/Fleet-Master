import SwiftUI

struct TripProgressView: View {
    let trip: Trip
    
    private var progress: Double {
        guard let actualStartTime = trip.actualStartTime else {
            return 0.0
        }
        
        let now = Date()
        let totalDuration = trip.scheduledEndTime.timeIntervalSince(trip.scheduledStartTime)
        let elapsedDuration = now.timeIntervalSince(actualStartTime)
        
        return min(max(elapsedDuration / totalDuration, 0.0), 1.0)
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .scheduled:
            return .blue
        case .ongoing:
            return .green
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private var isOverdue: Bool {
        if trip.status == .completed || trip.status == .cancelled {
            return false
        }
        return Date() > trip.scheduledEndTime
    }
    
    private var formattedDuration: String {
        let duration: TimeInterval
        if let actualEndTime = trip.actualEndTime {
            duration = actualEndTime.timeIntervalSince(trip.actualStartTime ?? trip.scheduledStartTime)
        } else if let actualStartTime = trip.actualStartTime {
            duration = Date().timeIntervalSince(actualStartTime)
        } else {
            duration = trip.scheduledEndTime.timeIntervalSince(trip.scheduledStartTime)
        }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress indicator
            ProgressView(value: progress)
                .tint(statusColor)
            
            // Duration text
            Text(formattedDuration)
                .foregroundColor(isOverdue ? .red : .primary)
                .font(.subheadline)
        }
        .padding()
    }
}

// MARK: - Preview Provider
struct TripProgressView_Previews: PreviewProvider {
    static var previews: some View {
        TripProgressView(trip: .previewTrip)
    }
} 
