//
//  JourneyModels.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 08/04/2025.
//
//
//  JourneyModels.swift
//  BetterMetro
//
//  Created on 08/04/2025.
//

import Foundation

// MARK: - Journey Stop Model
struct JourneyStop: Identifiable {
    let id = UUID().uuidString
    let stationId: String
    let stationName: String
    let time: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}

// MARK: - Journey Model
struct Journey: Identifiable {
    let id = UUID().uuidString
    let fromStation: Station
    let toStation: Station
    let departureTime: Date
    let arrivalTime: Date
    let line: String
    let stops: [JourneyStop]
    
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }
    
    var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalTime)
    }
    
    var durationInMinutes: Int {
        return Int(arrivalTime.timeIntervalSince(departureTime) / 60)
    }
}

// MARK: - Travel Time Type
enum TravelTimeType {
    case depart
    case arrive
}
