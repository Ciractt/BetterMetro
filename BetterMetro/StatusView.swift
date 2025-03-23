//
//  StatusView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

// StatusView.swift

import SwiftUI

struct StatusView: View {
    @StateObject private var disruptionService = DisruptionService()
    @State private var showingDetail = false
    @State private var selectedDisruption: Disruption?
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Line Status")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                    .padding(.horizontal)
                
                if disruptionService.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Loading status information...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let error = disruptionService.error {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .padding(.bottom)
                        Text("Failed to load status")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Try Again") {
                            disruptionService.fetchDisruptions()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                        .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                } else if disruptionService.disruptions.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                            .padding(.bottom)
                        Text("Good Service")
                            .font(.headline)
                        Text("All lines are running normally")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Service line status summary
                    HStack(spacing: 20) {
                        LineStatusSummary(
                            name: "Green Line",
                            hasDisruption: hasDisruptionForLine("green_line"),
                            disruptions: disruptionsForLine("green_line")
                        )
                        
                        LineStatusSummary(
                            name: "Yellow Line",
                            hasDisruption: hasDisruptionForLine("yellow_line"),
                            disruptions: disruptionsForLine("yellow_line")
                        )
                    }
                    .padding()
                    
                    Text("Status Updates")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(disruptionService.disruptions.sorted(by: { $0.order < $1.order })) { disruption in
                                DisruptionCard(disruption: disruption)
                                    .onTapGesture {
                                        // Set the selected disruption first, then show the sheet
                                        selectedDisruption = disruption
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            showingDetail = true
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding(.bottom, 90) // Make room for floating tab bar
        }
        .onAppear {
            // Manually load the disruptions
            disruptionService.isLoading = true
            disruptionService.error = nil
            
            // Build the URL with all required parameters
            var urlComponents = URLComponents(string: "https://ken.nebulalabs.cc/disruption/active/")
            urlComponents?.queryItems = [
                URLQueryItem(name: "facilities", value: "train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting"),
                URLQueryItem(name: "routes", value: "green_line,yellow_line"),
                URLQueryItem(name: "stations", value: "airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay"),
                URLQueryItem(name: "priority_levels", value: "service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other")
            ]
            
            guard let url = urlComponents?.url else {
                disruptionService.isLoading = false
                disruptionService.error = URLError(.badURL)
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    disruptionService.isLoading = false
                    
                    if let error = error {
                        disruptionService.error = error
                        return
                    }
                    
                    guard let data = data else {
                        disruptionService.error = URLError(.cannotParseResponse)
                        return
                    }
                    
                    do {
                        let disruptions = try JSONDecoder().decode([Disruption].self, from: data)
                        disruptionService.disruptions = disruptions
                    } catch {
                        disruptionService.error = error
                        print("Decoding error: \(error)")
                    }
                }
            }.resume()
        }
        .sheet(isPresented: $showingDetail, onDismiss: {
            // Clean up when sheet is dismissed
            selectedDisruption = nil
        }) {
            if let disruption = selectedDisruption {
                DisruptionDetailView(disruption: disruption)
            }
        }
    }
    
    // Helper methods
    private func hasDisruptionForLine(_ line: String) -> Bool {
        return disruptionService.disruptions.contains(where: {
            $0.impactedRoutes.contains(line) && $0.priorityLevel != "for_information_only"
        })
    }
    
    private func disruptionsForLine(_ line: String) -> [Disruption] {
        return disruptionService.disruptions.filter {
            $0.impactedRoutes.contains(line)
        }
    }
}

struct LineStatusSummary: View {
    let name: String
    let hasDisruption: Bool
    let disruptions: [Disruption]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(lineColor)
                    .frame(width: 12, height: 12)
                
                Text(name)
                    .font(.headline)
            }
            
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var lineColor: Color {
        return name == "Green Line" ? .green : .yellow
    }
    
    private var statusText: String {
        if hasDisruption {
            // Find the highest priority disruption
            if let highestPriority = disruptions
                .filter({ $0.priorityLevel != "for_information_only" })
                .sorted(by: { $0.order < $1.order })
                .first {
                return DisruptionService().nameForPriorityLevel(highestPriority.priorityLevel)
            }
            return "Disruption"
        } else {
            return "Good Service"
        }
    }
    
    private var textColor: Color {
        return hasDisruption ? .orange : .green
    }
}

struct DisruptionCard: View {
    let disruption: Disruption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PriorityLevelBadge(priorityLevel: disruption.priorityLevel)
                Spacer()
                Text(formattedDate(disruption.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(disruption.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(disruption.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if !disruption.impactedStations.isEmpty && !disruption.allStations {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(disruption.impactedStations, id: \.self) { station in
                            Text(formatStationName(station))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formatStationName(_ name: String) -> String {
        return name.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return dateString
    }
}

struct PriorityLevelBadge: View {
    let priorityLevel: String
    private let service = DisruptionService()
    
    var body: some View {
        Text(service.nameForPriorityLevel(priorityLevel))
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(service.colorForPriorityLevel(priorityLevel).opacity(0.2))
            )
            .foregroundColor(service.colorForPriorityLevel(priorityLevel))
    }
}

struct DisruptionDetailView: View {
    let disruption: Disruption
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        PriorityLevelBadge(priorityLevel: disruption.priorityLevel)
                        Spacer()
                        Text(formattedDate(disruption.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(disruption.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(disruption.content)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    if !disruption.impactedStations.isEmpty && !disruption.allStations {
                        VStack(alignment: .leading) {
                            Text("Affected Stations")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(disruption.impactedStations, id: \.self) { station in
                                    Text(formatStationName(station))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.tertiarySystemBackground))
                                        )
                                }
                            }
                        }
                    }
                    
                    if !disruption.impactedRoutes.isEmpty && !disruption.allRoutes {
                        VStack(alignment: .leading) {
                            Text("Affected Lines")
                                .font(.headline)
                            
                            HStack {
                                ForEach(disruption.impactedRoutes, id: \.self) { route in
                                    Text(formatRouteName(route))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(route == "green_line" ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                                        )
                                        .foregroundColor(route == "green_line" ? .green : .yellow)
                                }
                            }
                        }
                    }
                    
                    if !disruption.impactedFacilities.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Affected Facilities")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(disruption.impactedFacilities, id: \.self) { facility in
                                    Text(formatFacilityName(facility))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.tertiarySystemBackground))
                                        )
                                }
                            }
                        }
                    }
                    
                    if let infoTitle = disruption.additionalInfoTitle,
                       let infoUrl = disruption.additionalInfoUrl {
                        Divider()
                        
                        Link(destination: URL(string: infoUrl)!) {
                            HStack {
                                Text(infoTitle)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Status Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func formatStationName(_ name: String) -> String {
        return name.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private func formatRouteName(_ name: String) -> String {
        return name.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private func formatFacilityName(_ name: String) -> String {
        return name.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return dateString
    }
}

// A layout that wraps its children like text
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var position = CGPoint.zero
        var maxY: CGFloat = 0
        
        for (index, size) in sizes.enumerated() {
            // Move to the next line if this view won't fit
            if index > 0 && position.x + size.width > proposal.width ?? .infinity {
                position.x = 0
                position.y = maxY + spacing
            }
            
            // Update the layout's height
            maxY = max(maxY, position.y + size.height)
            
            // Advance horizontal position for the next view
            position.x += size.width + spacing
        }
        
        return CGSize(width: proposal.width ?? .infinity, height: maxY)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var position = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            
            // Move to the next line if this view won't fit
            if index > 0 && position.x + size.width > bounds.maxX {
                position.x = bounds.minX
                position.y += lineHeight + spacing
                lineHeight = 0
            }
            
            // Place the view
            subview.place(at: position, proposal: ProposedViewSize(size))
            
            // Track the line height
            lineHeight = max(lineHeight, size.height)
            
            // Advance horizontal position for the next view
            position.x += size.width + spacing
        }
    }
}

struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        StatusView()
    }
}
