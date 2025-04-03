import SwiftUI

struct TripDropdownMenu: View {
    @Binding var isExpanded: Bool
    @Binding var selectedTrip: Trip?
    let trips: [Trip]
    var onTripSelected: (Trip) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "map")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(selectedTrip?.title ?? "Select Trip")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(trips) { trip in
                            TripCard(trip: trip, isSelected: trip.id == selectedTrip?.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTrip = trip
                                        isExpanded = false
                                        onTripSelected(trip)
                                    }
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct TripCard: View {
    let trip: Trip
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(formatDateTime(trip.scheduledStartTime))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: trip.status)
            }
            
            // Route information
            VStack(spacing: 8) {
                RoutePoint(
                    icon: "circle.fill",
                    color: .green,
                    text: trip.startLocation
                )
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 20)
                    .padding(.leading, 11)
                
                RoutePoint(
                    icon: "mappin.circle.fill",
                    color: .red,
                    text: trip.endLocation
                )
            }
            
            if let distance = trip.distance {
                HStack(spacing: 16) {
                    Label(
                        String(format: "%.1f km", distance),
                        systemImage: "arrow.up.right.circle.fill"
                    )
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    
                    if let routeInfo = trip.routeInfo {
                        Label(
                            formatDuration(routeInfo.time),
                            systemImage: "clock.fill"
                        )
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d · h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

struct RoutePoint: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct StatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .scheduled:
            return Color.blue.opacity(0.1)
        case .inProgress:
            return Color.orange.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .cancelled:
            return Color.red.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}

// Preview
struct TripDropdownMenu_Previews: PreviewProvider {
    static var previews: some View {
        TripDropdownMenu(
            isExpanded: .constant(true),
            selectedTrip: .constant(nil),
            trips: [],
            onTripSelected: { _ in }
        )
        .padding()
        .background(Color.gray.opacity(0.2))
    }
} 