//
//  DisruptionModels.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

// DisruptionModels.swift

// DisruptionModels.swift

import Foundation

// MARK: - Disruption Model
struct Disruption: Identifiable, Codable, Hashable {
    let id: Int
    let createdAt: String
    let title: String
    let content: String
    let important: Bool
    let version: Int
    let order: Int
    let topics: String
    let additionalInfoTitle: String?
    let additionalInfoUrl: String?
    let guid: String
    let active: Bool
    let allRoutes: Bool
    let allStations: Bool
    let impactedStations: [String]
    let impactedRoutes: [String]
    let impactedFacilities: [String]
    let priorityLevel: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case content
        case important
        case version
        case order
        case topics
        case additionalInfoTitle = "additional_info_title"
        case additionalInfoUrl = "additional_info_url"
        case guid
        case active
        case allRoutes = "all_routes"
        case allStations = "all_stations"
        case impactedStations = "impacted_stations"
        case impactedRoutes = "impacted_routes"
        case impactedFacilities = "impacted_facilities"
        case priorityLevel = "priority_level"
    }
}

// MARK: - Disruption Service
class DisruptionService: ObservableObject {
    @Published var disruptions: [Disruption] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let baseURL = "https://ken.nebulalabs.cc/disruption/active/"
    
    func fetchDisruptions() {
        isLoading = true
        error = nil
        
        // Build the URL with all required parameters
        var urlComponents = URLComponents(string: baseURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "facilities", value: "train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting"),
            URLQueryItem(name: "routes", value: "green_line,yellow_line"),
            URLQueryItem(name: "stations", value: "airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay"),
            URLQueryItem(name: "priority_levels", value: "service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other")
        ]
        
        guard let url = urlComponents?.url else {
            self.error = URLError(.badURL)
            self.isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data else {
                    self.error = URLError(.cannotParseResponse)
                    return
                }
                
                do {
                    let disruptions = try JSONDecoder().decode([Disruption].self, from: data)
                    self.disruptions = disruptions
                } catch {
                    self.error = error
                    print("Decoding error: \(error)")
                }
            }
        }.resume()
    }
    
    // Helper method to get color for priority level
    func colorForPriorityLevel(_ priorityLevel: String) -> Color {
        switch priorityLevel {
        case "service_suspension":
            return .red
        case "service_disruption":
            return .orange
        case "station_closure":
            return .red
        case "facilities_out_of_use":
            return .yellow
        case "improvement_works":
            return .blue
        case "for_information_only":
            return .green
        default:
            return .gray
        }
    }
    
    // Helper method to get user-friendly name for priority level
    func nameForPriorityLevel(_ priorityLevel: String) -> String {
        switch priorityLevel {
        case "service_suspension":
            return "Service Suspended"
        case "service_disruption":
            return "Service Disruption"
        case "station_closure":
            return "Station Closed"
        case "facilities_out_of_use":
            return "Facilities Unavailable"
        case "improvement_works":
            return "Improvement Works"
        case "for_information_only":
            return "Information"
        default:
            return "Other"
        }
    }
}

import SwiftUI

extension Color {
    static func forPriorityLevel(_ priorityLevel: String) -> Color {
        switch priorityLevel {
        case "service_suspension":
            return .red
        case "service_disruption":
            return .orange
        case "station_closure":
            return .red
        case "facilities_out_of_use":
            return .yellow
        case "improvement_works":
            return .blue
        case "for_information_only":
            return .green
        default:
            return .gray
        }
    }
}
