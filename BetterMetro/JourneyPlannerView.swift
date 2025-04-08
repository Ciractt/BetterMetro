//
//  JourneyPlannerView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

import SwiftUI

struct JourneyPlannerView: View {
    // Station selection
    @State private var fromStation: Station?
    @State private var toStation: Station?
    @State private var showingFromStationPicker = false
    @State private var showingToStationPicker = false
    
    // Time selection
    @State private var travelTimeType: TravelTimeType = .depart
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    // Journey results
    @State private var showingResults = false
    @State private var journeyResults: [Journey] = []
    @State private var isLoading = false
    @State private var expandedJourneyId: String? = nil
    
    // Station list
    @State private var stations: [Station] = []
    @State private var isLoadingStations = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Journey Planner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Journey inputs
                        VStack(spacing: 12) {
                            // From station
                            Button(action: {
                                loadStations()
                                showingFromStationPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                    
                                    Text(fromStation?.name ?? "From")
                                        .fontWeight(fromStation == nil ? .regular : .semibold)
                                        .foregroundColor(fromStation == nil ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                            
                            // To station
                            Button(action: {
                                loadStations()
                                showingToStationPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                    
                                    Text(toStation?.name ?? "To")
                                        .fontWeight(toStation == nil ? .regular : .semibold)
                                        .foregroundColor(toStation == nil ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                            
                            // Time selection
                            HStack {
                                Picker("Time Type", selection: $travelTimeType) {
                                    Text("Depart").tag(TravelTimeType.depart)
                                    Text("Arrive").tag(TravelTimeType.arrive)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 150)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDatePicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.blue)
                                        
                                        Text(formattedDate(selectedDate))
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            
                            // Search button
                            Button(action: {
                                searchJourneys()
                            }) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Text("Search")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(canSearch ? Color.blue : Color.gray.opacity(0.5))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .disabled(!canSearch || isLoading)
                        }
                        .padding(.horizontal)
                        
                        // Results
                        if showingResults {
                            resultsView
                        }
                    }
                    .padding(.bottom, 100) // Extra padding for bottom tab bar
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(selectedDate: $selectedDate, travelTimeType: travelTimeType)
        }
        .sheet(isPresented: $showingFromStationPicker) {
            StationPickerView(stations: stations, selectedStation: $fromStation, isLoading: isLoadingStations)
        }
        .sheet(isPresented: $showingToStationPicker) {
            StationPickerView(stations: stations, selectedStation: $toStation, isLoading: isLoadingStations)
        }
    }
    
    // Results view
    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journey Options")
                .font(.headline)
                .padding(.horizontal)
            
            if journeyResults.isEmpty {
                Text("No journeys found for this route and time.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(journeyResults) { journey in
                    JourneyCard(
                        journey: journey,
                        isExpanded: expandedJourneyId == journey.id,
                        onTap: {
                            withAnimation {
                                if expandedJourneyId == journey.id {
                                    expandedJourneyId = nil
                                } else {
                                    expandedJourneyId = journey.id
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Check if search can be performed
    private var canSearch: Bool {
        return fromStation != nil && toStation != nil
    }
    
    // Format date for display
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Load stations
    private func loadStations() {
        guard stations.isEmpty && !isLoadingStations else { return }
        
        isLoadingStations = true
        
        JourneyService.shared.fetchStations { fetchedStations in
            self.stations = fetchedStations
            self.isLoadingStations = false
        }
    }
    
    // Search for journeys
    private func searchJourneys() {
        guard canSearch else { return }
        
        isLoading = true
        showingResults = false
        expandedJourneyId = nil
        
        // Use the JourneyService to plan a journey with real data
        // Pass the travel time type (depart/arrive) to the service
        JourneyService.shared.planJourney(
            from: fromStation!,
            to: toStation!,
            at: selectedDate,
            mode: travelTimeType
        ) { journeys in
            self.journeyResults = journeys
            self.isLoading = false
            self.showingResults = true
        }
    }
    
    // MARK: - Supporting Views
    
    // Date Picker View
    struct DatePickerView: View {
        @Binding var selectedDate: Date
        let travelTimeType: TravelTimeType
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            NavigationView {
                VStack {
                    DatePicker(
                        travelTimeType == .depart ? "Departure Time" : "Arrival Time",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding()
                    }
                }
                .navigationTitle(travelTimeType == .depart ? "Departure Time" : "Arrival Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // Station Picker View
    struct StationPickerView: View {
        let stations: [Station]
        @Binding var selectedStation: Station?
        let isLoading: Bool
        @State private var searchText = ""
        @Environment(\.presentationMode) var presentationMode
        
        var filteredStations: [Station] {
            if searchText.isEmpty {
                return stations
            } else {
                return stations.filter { $0.name.lowercased().contains(searchText.lowercased()) }
            }
        }
        
        var body: some View {
            NavigationView {
                VStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        List {
                            ForEach(filteredStations) { station in
                                Button(action: {
                                    selectedStation = station
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack {
                                        Text(station.name)
                                        
                                        Spacer()
                                        
                                        if station.id == selectedStation?.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .navigationTitle("Select Station")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search stations")
            }
        }
    }
    
    // Journey Card
    struct JourneyCard: View {
        let journey: Journey
        let isExpanded: Bool
        let onTap: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Card header
                Button(action: onTap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // Times
                            HStack(alignment: .center) {
                                Text(journey.formattedDepartureTime)
                                    .font(.system(size: 18, weight: .bold))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Text(journey.formattedArrivalTime)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            
                            // Duration
                            Text("\(journey.durationInMinutes) min \(isExpanded ? "• \(journey.stops.count) stops" : "")")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Line indicator
                        LineIndicator(lineName: journey.line)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    .padding()
                }
                .buttonStyle(PlainButtonStyle())
                
                // Expanded details
                if isExpanded {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Show journey steps
                        ForEach(journey.stops.indices, id: \.self) { index in
                            let stop = journey.stops[index]
                            
                            HStack(alignment: .top) {
                                // Step indicator
                                VStack(spacing: 0) {
                                    // Current station dot
                                    Circle()
                                        .frame(width: 10, height: 10)
                                        .foregroundColor(index == 0 ? .green : (index == journey.stops.count - 1 ? .red : .gray))
                                    
                                    // Line to next station (except for last stop)
                                    if index < journey.stops.count - 1 {
                                        Rectangle()
                                            .frame(width: 2)
                                            .foregroundColor(Color(journey.line == "GREEN_LINE" ? .green : .yellow))
                                            .padding(.vertical, 0)
                                    }
                                }
                                .frame(width: 20)
                                .frame(height: index < journey.stops.count - 1 ? 40 : 20)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stop.stationName)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text(stop.formattedTime)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // Line Indicator
    struct LineIndicator: View {
        let lineName: String
        
        var body: some View {
            Text(lineName == "GREEN_LINE" ? "Green" : "Yellow")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(lineName == "GREEN_LINE" ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                .foregroundColor(lineName == "GREEN_LINE" ? .green : .yellow)
                .cornerRadius(6)
        }
    }
    

}
