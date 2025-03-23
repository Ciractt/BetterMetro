//
//  MetroDataModels.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

/// MetroDataModels.swift

import Foundation
import CoreLocation

// MARK: - Station Model
struct Station: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    
    // Custom initializer for creating stations manually
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Platform Model
struct Platform: Identifiable, Hashable {
    let id: String
    let platformNumber: Int
    let direction: String
    let helperText: String
    let coordinates: Coordinates
    let stationId: String
    
    init(id: String, platformNumber: Int, direction: String, helperText: String, coordinates: Coordinates, stationId: String) {
        self.id = id
        self.platformNumber = platformNumber
        self.direction = direction
        self.helperText = helperText
        self.coordinates = coordinates
        self.stationId = stationId
    }
}

// MARK: - Coordinates Model
struct Coordinates: Codable, Hashable {
    let longitude: Double
    let latitude: Double
    
    var clCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Train Time Model
struct TrainTime: Identifiable, Codable, Hashable {
    let id: String
    let trn: String
    let lastEvent: String
    let lastEventLocation: String
    let lastEventTime: Date
    let destination: String
    let dueIn: Int
    let line: String
    let actualScheduledTime: Date
    let actualPredictedTime: Date
    
    init(id: String, trn: String, lastEvent: String, lastEventLocation: String, lastEventTime: Date, destination: String, dueIn: Int, line: String, actualScheduledTime: Date, actualPredictedTime: Date) {
        self.id = id
        self.trn = trn
        self.lastEvent = lastEvent
        self.lastEventLocation = lastEventLocation
        self.lastEventTime = lastEventTime
        self.destination = destination
        self.dueIn = dueIn
        self.line = line
        self.actualScheduledTime = actualScheduledTime
        self.actualPredictedTime = actualPredictedTime
    }
}

// MARK: - API Response Types
typealias StationsResponse = [String: String]
// We won't use PlatformsResponse as we'll parse that manually

// MARK: - API Services
class MetroAPIService: ObservableObject {
    static let shared = MetroAPIService()
    
    private let baseURL = "https://metro-rti.nexus.org.uk/api"
    private let userAgent = "okhttp/3.12.1"
    
    @Published var stations: [Station] = []
    @Published var platforms: [String: [Platform]] = [:]
    @Published var trainTimes: [String: [TrainTime]] = [:]
    
    private init() {}
    
    // MARK: - Data Fetching Methods
    
    func fetchStations(completion: @escaping (Result<[Station], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/stations") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLError(.cannotParseResponse)))
                return
            }
            
            do {
                let stationsDict = try JSONDecoder().decode([String: String].self, from: data)
                let stationList = stationsDict.map { Station(id: $0.key, name: $0.value) }
                    .sorted { $0.name < $1.name }
                
                DispatchQueue.main.async {
                    self.stations = stationList
                    completion(.success(stationList))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchPlatforms(completion: @escaping (Result<[String: [Platform]], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/stations/platforms") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLError(.cannotParseResponse)))
                return
            }
            
            do {
                // First decode the JSON as a dictionary
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]] {
                    var result: [String: [Platform]] = [:]
                    
                    // Parse the platforms dictionary
                    for (stationId, platformsData) in jsonObject {
                        var platforms: [Platform] = []
                        
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
                                platforms.append(platform)
                            }
                        }
                        
                        result[stationId] = platforms
                    }
                    
                    DispatchQueue.main.async {
                        self.platforms = result
                        completion(.success(result))
                    }
                } else {
                    throw URLError(.cannotParseResponse)
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchTrainTimes(stationId: String, platformNumber: Int, completion: @escaping (Result<[TrainTime], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/times/\(stationId)/\(platformNumber)") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLError(.cannotParseResponse)))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let trainTimes = try decoder.decode([TrainTime].self, from: data)
                
                DispatchQueue.main.async {
                    self.trainTimes["\(stationId)_\(platformNumber)"] = trainTimes
                    completion(.success(trainTimes))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
