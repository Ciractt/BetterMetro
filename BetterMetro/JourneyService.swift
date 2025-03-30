//
//  JourneyService.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 28/03/2025.
//


// JourneyService.swift

import Foundation
import Combine

class JourneyService {
    static let shared = JourneyService()
    
    private let baseURL = "https://metro-rti.nexus.org.uk/api"
    private let userAgent = "okhttp/3.12.1"
    private var stations: [Station] = []
    private var platforms: [String: [Platform]] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // Fetch all stations
    func fetchStations(completion: @escaping ([Station]) -> Void) {
        // Check if we already have stations cached
        if !stations.isEmpty {
            completion(stations)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/stations") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [String: String].self, decoder: JSONDecoder())
            .map { stationsDict in
                stationsDict.map { Station(id: $0.key, name: $0.value) }
                    .sorted { $0.name < $1.name }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] stations in
                self?.stations = stations
                completion(stations)
            })
            .store(in: &cancellables)
    }
    
    // Fetch all platforms
    func fetchPlatforms(completion: @escaping ([String: [Platform]]) -> Void) {
        // Check if we already have platforms cached
        if !platforms.isEmpty {
            completion(platforms)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/stations/platforms") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]] {
                    var platformsDict: [String: [Platform]] = [:]
                    
                    for (stationId, platformsData) in jsonObject {
                        var stationPlatforms: [Platform] = []
                        
                        for platformData in platformsData {
                            if let platformNumber = platformData["platformNumber"] as? Int,
                               let direction = platformData["direction"] as? String,
                               let helperText = platformData["helperText"] as? String,
                               let coordinatesData = platformData["coordinates"] as? [String: Double],
                               let longitude = coordinatesData["longitude"],
                               let latitude = coordinatesData["latitude"] {
                                
                                let coordinates = Coordinates(longitude: longitude, latitude: latitude)
                                let platform = Platform(
                                    id: "\(stationId)_\(platformNumber)",
                                    platformNumber: platformNumber,
                                    direction: direction,
                                    helperText: helperText,
                                    coordinates: coordinates,
                                    stationId: stationId
                                )
                                stationPlatforms.append(platform)
                            }
                        }
                        
                        platformsDict[stationId] = stationPlatforms
                    }
                    
                    self?.platforms = platformsDict
                    
                    DispatchQueue.main.async {
                        completion(platformsDict)
                    }
                }
            } catch {
                print("Error parsing platforms: \(error)")
            }
        }.resume()
    }
    
    // Fetch real-time train information for a specific platform
    func fetchTrainTimes(stationId: String, platformNumber: Int, completion: @escaping ([TrainTime]) -> Void) {
        guard let url = URL(string: "\(baseURL)/times/\(stationId)/\(platformNumber)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let trainTimes = try decoder.decode([TrainTime].self, from: data)
                
                DispatchQueue.main.async {
                    completion(trainTimes)
                }
            } catch {
                print("Error parsing train times: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
    
    // Generate journeys based on real-time data
    func planJourney(from fromStation: Station, to toStation: Station, at departureTime: Date, completion: @escaping ([Journey]) -> Void) {
        // First, fetch platforms to determine which platforms to use
        fetchPlatforms { [weak self] platformsDict in
            guard let self = self else { return }
            
            // Get platforms for fromStation
            guard let fromPlatforms = platformsDict[fromStation.id] else {
                completion([])
                return
            }
            
            // Determine which platform to use based on direction to destination
            let fromPlatform = self.determineBestPlatform(fromStationId: fromStation.id, toStationId: toStation.id, platforms: fromPlatforms)
            
            // Fetch real-time train information for the departure platform
            self.fetchTrainTimes(stationId: fromStation.id, platformNumber: fromPlatform.platformNumber) { trainTimes in
                // Filter and sort trains by departure time
                let relevantTrains = trainTimes
                    .filter { $0.actualPredictedTime > departureTime }
                    .sorted { $0.actualPredictedTime < $1.actualPredictedTime }
                    .prefix(4) // Get up to 4 journey options
                
                var journeys: [Journey] = []
                
                // Create journeys based on train times
                for train in relevantTrains {
                    // Calculate journey details
                    let line = train.line == "GREEN" ? "GREEN_LINE" : "YELLOW_LINE"
                    
                    // Estimate arrival time (in a real app, you'd query for this)
                    let journeyDuration = self.estimateJourneyDuration(from: fromStation.id, to: toStation.id, line: line)
                    let arrivalTime = train.actualPredictedTime.addingTimeInterval(TimeInterval(journeyDuration * 60))
                    
                    // Generate stops - in a real implementation, you would get the actual route
                    let stops = self.generateJourneyStops(fromStation: fromStation, toStation: toStation, departureTime: train.actualPredictedTime, arrivalTime: arrivalTime, line: line)
                    
                    let journey = Journey(
                        fromStation: fromStation,
                        toStation: toStation,
                        departureTime: train.actualPredictedTime,
                        arrivalTime: arrivalTime,
                        line: line,
                        stops: stops
                    )
                    
                    journeys.append(journey)
                }
                
                // If we couldn't find enough real journeys, add some estimated ones
                if journeys.count < 4 {
                    let additionalJourneys = self.generateAdditionalJourneys(
                        fromStation: fromStation,
                        toStation: toStation,
                        departureTime: departureTime,
                        existingJourneys: journeys,
                        count: 4 - journeys.count
                    )
                    journeys.append(contentsOf: additionalJourneys)
                }
                
                completion(journeys)
            }
        }
    }
    
    // Determine which platform to use based on travel direction
    private func determineBestPlatform(fromStationId: String, toStationId: String, platforms: [Platform]) -> Platform {
        // Default to the first platform if we can't determine
        guard let defaultPlatform = platforms.first else {
            fatalError("No platforms available for station")
        }
        
        // Determine which line and direction based on station IDs
        let line = determineMetroLine(from: fromStationId, to: toStationId)
        let isInbound = isInboundJourney(from: fromStationId, to: toStationId, line: line)
        
        // Find platform with matching direction
        if isInbound {
            return platforms.first { $0.direction == "IN" } ?? defaultPlatform
        } else {
            return platforms.first { $0.direction == "OUT" } ?? defaultPlatform
        }
    }
    
    // Determine which Metro line connects the stations
    private func determineMetroLine(from: String, to: String) -> String {
        // List of Green Line stations
        let greenLineStations = ["APT", "CAL", "BFT", "KSP", "RGC", "FAW", "WBR", "ILF", "SGF", "JES", "HAY", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "BYW", "EBO", "SBN", "UNI", "PLI", "SFC", "MLF", "PAL", "SHL"]
        
        // Check if both stations are on the Green Line
        if greenLineStations.contains(from) && greenLineStations.contains(to) {
            return "GREEN_LINE"
        } else {
            return "YELLOW_LINE"
        }
    }
    
    // Determine if the journey is inbound
    private func isInboundJourney(from: String, to: String, line: String) -> Bool {
        // This is a simplified approximation - in a real app, you'd use actual route data
        if line == "GREEN_LINE" {
            // For Green Line: Airport (APT) to South Hylton (SHL) is the route
            // Stations closer to APT than the destination are outbound
            let greenLineOrdering = ["APT", "CAL", "BFT", "KSP", "RGC", "FAW", "WBR", "ILF", "SGF", "JES", "HAY", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "BYW", "EBO", "SBN", "UNI", "PLI", "SFC", "MLF", "PAL", "SHL"]
            
            if let fromIndex = greenLineOrdering.firstIndex(of: from),
               let toIndex = greenLineOrdering.firstIndex(of: to) {
                return fromIndex < toIndex
            }
        } else {
            // For Yellow Line: St James (SJM) to South Shields (SSS) is the route
            let yellowLineOrdering = ["SJM", "MTS", "HAY", "JES", "WJS", "ILF", "SGF", "LBN", "FLE", "BTN", "PMV", "SMR", "NPK", "WMN", "MSN", "CUL", "WTL", "TYN", "NSH", "MWL", "PCM", "HOW", "HDR", "WSD", "WKG", "CRD", "BYK", "MAN", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "HEB", "JAR", "BDE", "SMD", "TDK", "CHI", "SSS"]
            
            if let fromIndex = yellowLineOrdering.firstIndex(of: from),
               let toIndex = yellowLineOrdering.firstIndex(of: to) {
                return fromIndex < toIndex
            }
        }
        
        // Default to inbound if we can't determine
        return true
    }
    
    // Estimate journey duration between stations
    private func estimateJourneyDuration(from: String, to: String, line: String) -> Int {
        // This would ideally use actual timetable data
        // For now, we'll use a simple heuristic
        
        // Approximate time between stations (in minutes)
        let stationTransitTime = 3
        
        // Get the station ordering for the relevant line
        let stationOrdering: [String]
        if line == "GREEN_LINE" {
            stationOrdering = ["APT", "CAL", "BFT", "KSP", "RGC", "FAW", "WBR", "ILF", "SGF", "JES", "HAY", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "BYW", "EBO", "SBN", "UNI", "PLI", "SFC", "MLF", "PAL", "SHL"]
        } else {
            stationOrdering = ["SJM", "MTS", "HAY", "JES", "WJS", "ILF", "SGF", "LBN", "FLE", "BTN", "PMV", "SMR", "NPK", "WMN", "MSN", "CUL", "WTL", "TYN", "NSH", "MWL", "PCM", "HOW", "HDR", "WSD", "WKG", "CRD", "BYK", "MAN", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "HEB", "JAR", "BDE", "SMD", "TDK", "CHI", "SSS"]
        }
        
        // Find the indices of the stations
        guard let fromIndex = stationOrdering.firstIndex(of: from),
              let toIndex = stationOrdering.firstIndex(of: to) else {
            // Default duration if we can't determine
            return 30
        }
        
        // Calculate number of stations between
        let stationCount = abs(toIndex - fromIndex)
        
        // Calculate total transit time
        return stationCount * stationTransitTime
    }
    
    // Generate journey stops for a route
    private func generateJourneyStops(fromStation: Station, toStation: Station, departureTime: Date, arrivalTime: Date, line: String) -> [JourneyStop] {
        var stops: [JourneyStop] = []
        
        // Starting station
        stops.append(JourneyStop(
            stationId: fromStation.id,
            stationName: fromStation.name,
            time: departureTime
        ))
        
        // Get the station ordering for the line
        let stationOrdering: [String]
        if line == "GREEN_LINE" {
            stationOrdering = ["APT", "CAL", "BFT", "KSP", "RGC", "FAW", "WBR", "ILF", "SGF", "JES", "HAY", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "BYW", "EBO", "SBN", "UNI", "PLI", "SFC", "MLF", "PAL", "SHL"]
        } else {
            stationOrdering = ["SJM", "MTS", "HAY", "JES", "WJS", "ILF", "SGF", "LBN", "FLE", "BTN", "PMV", "SMR", "NPK", "WMN", "MSN", "CUL", "WTL", "TYN", "NSH", "MWL", "PCM", "HOW", "HDR", "WSD", "WKG", "CRD", "BYK", "MAN", "MTS", "CEN", "GHD", "GST", "FEL", "HTH", "PLW", "HEB", "JAR", "BDE", "SMD", "TDK", "CHI", "SSS"]
        }
        
        // Find station indices
        guard let fromIndex = stationOrdering.firstIndex(of: fromStation.id),
              let toIndex = stationOrdering.firstIndex(of: toStation.id) else {
            // If we can't find the stations, just return origin and destination
            stops.append(JourneyStop(
                stationId: toStation.id,
                stationName: toStation.name,
                time: arrivalTime
            ))
            return stops
        }
        
        // Determine direction
        let ascending = fromIndex < toIndex
        let startIndex = min(fromIndex, toIndex)
        let endIndex = max(fromIndex, toIndex)
        
        // Collect intermediate stations
        var intermediateStations: [(String, String)] = []
        for i in startIndex+1..<endIndex {
            let stationId = stationOrdering[i]
            // Find the station name from our cached stations
            if let station = stations.first(where: { $0.id == stationId }) {
                intermediateStations.append((stationId, station.name))
            }
        }
        
        // If we need to reverse the order
        if !ascending {
            intermediateStations.reverse()
        }
        
        // Calculate total journey time
        let totalJourneySeconds = arrivalTime.timeIntervalSince(departureTime)
        let secondsPerStop = totalJourneySeconds / Double(intermediateStations.count + 1)
        
        // Add intermediate stops
        for (i, station) in intermediateStations.enumerated() {
            let stopTime = departureTime.addingTimeInterval(secondsPerStop * Double(i + 1))
            stops.append(JourneyStop(
                stationId: station.0,
                stationName: station.1,
                time: stopTime
            ))
        }
        
        // Add destination
        stops.append(JourneyStop(
            stationId: toStation.id,
            stationName: toStation.name,
            time: arrivalTime
        ))
        
        return stops
    }
    
    // Generate additional estimated journeys when we don't have enough real data
    private func generateAdditionalJourneys(fromStation: Station, toStation: Station, departureTime: Date, existingJourneys: [Journey], count: Int) -> [Journey] {
        var additionalJourneys: [Journey] = []
        
        let line = determineMetroLine(from: fromStation.id, to: toStation.id)
        let journeyDuration = estimateJourneyDuration(from: fromStation.id, to: toStation.id, line: line)
        
        // Get the latest departure time from existing journeys
        var latestDepartureTime = departureTime
        if let lastJourney = existingJourneys.last {
            latestDepartureTime = lastJourney.departureTime
        }
        
        // Generate additional journeys
        for i in 0..<count {
            // Add 10 minutes for each additional journey
            let newDepartureTime = latestDepartureTime.addingTimeInterval(TimeInterval((i + 1) * 10 * 60))
            let newArrivalTime = newDepartureTime.addingTimeInterval(TimeInterval(journeyDuration * 60))
            
            let stops = generateJourneyStops(fromStation: fromStation, toStation: toStation, departureTime: newDepartureTime, arrivalTime: newArrivalTime, line: line)
            
            let journey = Journey(
                fromStation: fromStation,
                toStation: toStation,
                departureTime: newDepartureTime,
                arrivalTime: newArrivalTime,
                line: line,
                stops: stops
            )
            
            additionalJourneys.append(journey)
        }
        
        return additionalJourneys
    }
}
