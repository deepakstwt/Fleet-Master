import SwiftUI

struct ScheduledTripsCalendarView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @State private var selectedDate: Date = Date()
    @State private var calendarViewType: CalendarViewType = .month
    @State private var showingTripDetail = false
    @State private var selectedTrip: Trip?
    @State private var showingAddTrip = false
    
    enum CalendarViewType: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with controls
            calendarHeader
            
            // View type selector
            viewTypeSelector
            
            // Main calendar content
            ScrollView {
                VStack(spacing: 16) {
                    // Month view with dates
                    if calendarViewType == .month {
                        monthCalendarView
                    } else if calendarViewType == .week {
                        weekCalendarView
                    } else {
                        dayCalendarView
                    }
                    
                    // Event list for selected day
                    eventsList
                }
                .padding()
            }
        }
        .navigationTitle("Trip Schedule")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddTrip = true
                }) {
                    Label("Add Trip", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingTripDetail) {
            if let trip = selectedTrip {
                NavigationStack {
                    TripDetailView(trip: trip)
                }
            }
        }
        .fullScreenCover(isPresented: $showingAddTrip) {
            NavigationStack {
                AddTripView()
                    .environmentObject(tripViewModel)
                    .environmentObject(driverViewModel)
                    .environmentObject(vehicleViewModel)
            }
        }
    }
    
    // MARK: - Calendar Components
    
    private var calendarHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(monthYearFormatter.string(from: selectedDate))
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    moveDate(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    selectedDate = Date()
                }) {
                    Text("Today")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    moveDate(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var viewTypeSelector: some View {
        Picker("Calendar View", selection: $calendarViewType) {
            ForEach(CalendarViewType.allCases) { viewType in
                Text(viewType.rawValue).tag(viewType)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var monthCalendarView: some View {
        VStack(spacing: 12) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            let daysInMonth = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    let day = daysInMonth[index]
                    if day.date != nil {
                        DayCell(
                            date: day.date!,
                            isSelected: calendar.isDate(day.date!, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day.date!),
                            events: tripsForDate(day.date!),
                            onSelect: {
                                withAnimation {
                                    selectedDate = day.date!
                                }
                            }
                        )
                    } else {
                        // Empty cell for days outside current month
                        Text("")
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(.vertical)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .padding(.horizontal, 2)
    }
    
    private var weekCalendarView: some View {
        VStack(spacing: 12) {
            // Week view with dates
            HStack {
                ForEach(daysInSelectedWeek(), id: \.self) { date in
                    VStack(spacing: 8) {
                        Text(weekdayFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 16, weight: calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular))
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.blue : Color.clear)
                            )
                        
                        let trips = tripsForDate(date)
                        if !trips.isEmpty {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.vertical)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            
            // Timeline for the selected day
            TimelineView()
                .frame(height: 500)
                .padding(.top, 8)
        }
    }
    
    private var dayCalendarView: some View {
        VStack(spacing: 0) {
            // Day header
            HStack(spacing: 20) {
                ForEach(-1...1, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: selectedDate)!
                    DayHeader(
                        date: date,
                        isSelected: offset == 0,
                        onSelect: {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .padding(.vertical)
            
            // Timeline for the selected day
            TimelineView()
                .frame(height: 600)
        }
    }
    
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scheduled Trips")
                .font(.headline)
            
            let trips = tripsForDate(selectedDate)
            
            if trips.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No trips scheduled for this day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ForEach(trips) { trip in
                    TripEventCard(
                        trip: trip,
                        driverName: driverViewModel.getDriverById(trip.driverId ?? "")?.name ?? "Unassigned",
                        vehicleName: formatVehicle(vehicleViewModel.getVehicleById(trip.vehicleId ?? "")),
                        onTap: {
                            selectedTrip = trip
                            showingTripDetail = true
                        }
                    )
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Views
    
    struct DayCell: View {
        let date: Date
        let isSelected: Bool
        let isToday: Bool
        let events: [Trip]
        let onSelect: () -> Void
        
        private let calendar = Calendar.current
        
        var body: some View {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.2) : Color.clear))
                    )
                
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(events.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(eventDotColor(for: events[0].status))
                                .frame(width: 4, height: 4)
                        }
                        
                        if events.count > 3 {
                            Text("+\(events.count - 3)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
        
        private func eventDotColor(for status: TripStatus) -> Color {
            switch status {
            case .scheduled:
                return .blue
            case .ongoing:
                return .orange
            case .completed:
                return .green
            case .cancelled:
                return .gray
            }
        }
    }
    
    struct DayHeader: View {
        let date: Date
        let isSelected: Bool
        let onSelect: () -> Void
        
        private let calendar = Calendar.current
        private let weekdayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter
        }()
        
        var body: some View {
            VStack(spacing: 8) {
                Text(weekdayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.title3)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.clear)
                    )
            }
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
    }
    
    struct TimelineView: View {
        // This would be a placeholder for a more complex timeline view
        // In a production app, this would show hour blocks with events
        // positioned according to their time slots
        
        var body: some View {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(7..<20, id: \.self) { hour in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("\(hour):00")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 1)
                                }
                                .padding(.bottom, 30)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    struct TripEventCard: View {
        let trip: Trip
        let driverName: String
        let vehicleName: String
        let onTap: () -> Void
        
        private let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter
        }()
        
        var body: some View {
            HStack {
                // Colored status indicator
                Rectangle()
                    .fill(statusColor(trip.status))
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.title)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text("\(timeFormatter.string(from: trip.scheduledStartTime)) - \(timeFormatter.string(from: trip.scheduledEndTime))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(status: trip.status)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 24) {
                        Label {
                            Text(driverName)
                                .font(.caption)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Label {
                            Text(vehicleName)
                                .font(.caption)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "car.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .onTapGesture {
                onTap()
            }
        }
        
        private func statusColor(_ status: TripStatus) -> Color {
            switch status {
            case .scheduled:
                return .blue
            case .ongoing:
                return .orange
            case .completed:
                return .green
            case .cancelled:
                return .gray
            }
        }
    }
    
    struct StatusBadge: View {
        let status: TripStatus
        
        var body: some View {
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(12)
        }
        
        private var backgroundColor: Color {
            switch status {
            case .scheduled:
                return Color.blue.opacity(0.2)
            case .ongoing:
                return Color.orange.opacity(0.2)
            case .completed:
                return Color.green.opacity(0.2)
            case .cancelled:
                return Color.gray.opacity(0.2)
            }
        }
        
        private var foregroundColor: Color {
            switch status {
            case .scheduled:
                return .blue
            case .ongoing:
                return .orange
            case .completed:
                return .green
            case .cancelled:
                return .gray
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func tripsForDate(_ date: Date) -> [Trip] {
        tripViewModel.trips.filter { trip in
            calendar.isDate(trip.scheduledStartTime, inSameDayAs: date)
        }
    }
    
    private func moveDate(by amount: Int) {
        switch calendarViewType {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: amount, to: selectedDate)!
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: amount, to: selectedDate)!
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: amount, to: selectedDate)!
        }
    }
    
    private func daysInSelectedWeek() -> [Date] {
        let startOfWeek = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: selectedDate
            )
        )!
        
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
    
    private struct MonthDay {
        let date: Date?
        let day: Int?
    }
    
    private func generateDaysInMonth() -> [MonthDay] {
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 0
        
        var days: [MonthDay] = []
        
        // Add empty cells for days before the start of the month
        for _ in 0..<offsetDays {
            days.append(MonthDay(date: nil, day: nil))
        }
        
        // Add cells for each day in the month
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(MonthDay(date: date, day: day))
            }
        }
        
        // Add empty cells to complete the grid (if needed)
        let remainingCells = 42 - days.count // 6 rows of 7 days
        if remainingCells > 0 && remainingCells < 7 {
            for _ in 0..<remainingCells {
                days.append(MonthDay(date: nil, day: nil))
            }
        }
        
        return days
    }
    
    private func formatVehicle(_ vehicle: Vehicle?) -> String {
        guard let vehicle = vehicle else { return "Unassigned" }
        return "\(vehicle.make) \(vehicle.model)"
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        
        var symbols = formatter.shortWeekdaySymbols ?? []
        
        // Adjust the weekday symbols to start with the locale's first weekday
        let firstWeekday = calendar.firstWeekday
        if firstWeekday > 1 {
            for _ in 1..<firstWeekday {
                if let first = symbols.first {
                    symbols.append(first)
                    symbols.removeFirst()
                }
            }
        }
        
        return symbols.map { String($0.prefix(1)) }
    }
    
    private let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ScheduledTripsCalendarView()
            .environmentObject(TripViewModel())
            .environmentObject(DriverViewModel())
            .environmentObject(VehicleViewModel())
    }
} 
