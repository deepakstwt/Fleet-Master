import SwiftUI

struct FleetManagerControlsView: View {
    // Statistics
    let activeCount: Int
    let scheduledCount: Int
    let driversCount: Int
    
    // Filters
    @Binding var showAttentionNeeded: Bool
    @Binding var showInProgress: Bool
    
    // Actions
    var onTrackAllVehicles: () -> Void
    var onOptimizeRoutes: () -> Void
    
    // State for optimization
    @State private var isOptimizing = false
    @State private var showOptimizationAlert = false
    @State private var optimizationMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Fleet Manager Controls")
                .font(.headline)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            
            Divider()
            
            // Statistics
            HStack(spacing: 0) {
                statView(count: activeCount, label: "Active", color: .blue)
                
                Divider().frame(height: 30)
                
                statView(count: scheduledCount, label: "Scheduled", color: .orange)
                
                Divider().frame(height: 30)
                
                statView(count: driversCount, label: "Drivers", color: .green)
            }
            .padding(.vertical, 16)
            .background(Color.white)
            
            Divider()
            
            // Filters section
            VStack(alignment: .leading, spacing: 12) {
                Text("Filter Active Trips")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                HStack(spacing: 16) {
                    filterButton(
                        isSelected: $showAttentionNeeded,
                        icon: "exclamationmark.triangle.fill",
                        label: "Attention Needed",
                        color: .orange
                    )
                    
                    filterButton(
                        isSelected: $showInProgress,
                        icon: "arrow.up.forward.app.fill",
                        label: "In Progress",
                        color: .blue
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.white)
            
            Divider()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onTrackAllVehicles) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Track All Vehicles")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    isOptimizing = true
                    optimizationMessage = "Optimizing routes..."
                    showOptimizationAlert = true
                    
                    // Simulate optimization process
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        optimizationMessage = """
                        Routes optimized successfully!
                        • Reduced total distance by 15%
                        • Estimated fuel savings: 12%
                        • Expected time savings: 25 minutes
                        """
                        isOptimizing = false
                        onOptimizeRoutes()
                    }
                }) {
                    HStack {
                        if isOptimizing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.swap")
                        }
                        Text(isOptimizing ? "Optimizing..." : "Optimize Routes")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isOptimizing ? Color.blue.opacity(0.7) : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isOptimizing)
            }
            .padding(16)
            .background(Color.white)
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(width: 280)
        .alert(isPresented: $showOptimizationAlert) {
            Alert(
                title: Text("Route Optimization"),
                message: Text(optimizationMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func statView(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func filterButton(isSelected: Binding<Bool>, icon: String, label: String, color: Color) -> some View {
        Button(action: {
            isSelected.wrappedValue.toggle()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected.wrappedValue ? Color(color.opacity(0.1)) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected.wrappedValue ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FleetManagerControlsView_Previews: PreviewProvider {
    static var previews: some View {
        FleetManagerControlsView(
            activeCount: 0,
            scheduledCount: 2,
            driversCount: 2,
            showAttentionNeeded: .constant(false),
            showInProgress: .constant(true),
            onTrackAllVehicles: {},
            onOptimizeRoutes: {}
        )
        .padding()
        .background(Color.gray.opacity(0.2))
    }
} 