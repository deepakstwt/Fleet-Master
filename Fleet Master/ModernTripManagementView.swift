import SwiftUI

struct ModernTripManagementView: View {
    @State private var searchText = ""
    @State private var selectedViewMode: ModernViewMode = .list
    @State private var customTrips: [CustomTrip] = []
    
    enum ModernViewMode {
        case list, calendar, map
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar with background blur
                    VStack(spacing: 16) {
                        // Status cards
                        statusCardsSection
                        
                        // Search bar
                        searchBarView
                        
                        // View mode selector
                        viewModeSelectorView
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .background {
                        Color.white
                            .opacity(0.5)
                            .background(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Main content area
                    ZStack {
                        if customTrips.isEmpty {
                            emptyStateView
                        } else {
                            // Trip list would go here
                            Text("Trips would appear here")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Trip Management")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addTripButton
                    }
                }
            }
        }
    }
    
    // MARK: - Status Cards Section
    
    private var statusCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statusCard(title: "Scheduled", count: 3, icon: "calendar", color: .blue)
                statusCard(title: "In Progress", count: 1, icon: "airplane.departure", color: .yellow)
                statusCard(title: "Completed", count: 5, icon: "checkmark.circle", color: .green)
                statusCard(title: "Cancelled", count: 2, icon: "xmark.circle", color: .red)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
    
    private func statusCard(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: 130, height: 90)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField("Search trips...", text: $searchText)
                .font(.body)
                .padding(.vertical, 10)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - View Mode Selector
    
    private var viewModeSelectorView: some View {
        HStack(spacing: 8) {
            viewModeButton(mode: .list, icon: "list.bullet")
            viewModeButton(mode: .calendar, icon: "calendar")
            viewModeButton(mode: .map, icon: "map")
        }
        .padding(4)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func viewModeButton(mode: ModernViewMode, icon: String) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedViewMode = mode
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selectedViewMode == mode ? .white : .secondary)
                .frame(width: 90, height: 36)
                .background {
                    if selectedViewMode == mode {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text("No Trips Found")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Start by adding your first trip")
                .font(.footnote)
                .foregroundColor(Color(UIColor.systemGray2))
        }
        .padding()
    }
    
    // MARK: - Add Trip Button
    
    private var addTripButton: some View {
        Button(action: {
            // Add trip action
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Trip")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - Preview Models

struct CustomTrip: Identifiable {
    var id = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var status: CustomTripStatus
    
    enum CustomTripStatus {
        case scheduled, inProgress, completed, cancelled
    }
}

// MARK: - Preview
struct ModernTripManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ModernTripManagementView()
    }
} 