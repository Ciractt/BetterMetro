//
//  StationExtension.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 28/03/2025.
//


// StationExtension.swift

import Foundation

extension Station {
    static func getMockStations() -> [Station] {
        return [
            Station(id: "APT", name: "Airport"),
            Station(id: "BDE", name: "Bede"),
            Station(id: "BFT", name: "Bank Foot"),
            Station(id: "BTN", name: "Benton"),
            Station(id: "BYK", name: "Byker"),
            Station(id: "BYW", name: "Brockley Whins"),
            Station(id: "CAL", name: "Callerton Parkway"),
            Station(id: "CEN", name: "Central Station"),
            Station(id: "CHI", name: "Chichester"),
            Station(id: "CRD", name: "Chillingham Road"),
            Station(id: "CUL", name: "Cullercoats"),
            Station(id: "HAY", name: "Haymarket"),
            Station(id: "HTH", name: "Heworth"),
            Station(id: "MTS", name: "Monument"),
            Station(id: "SGF", name: "South Gosforth"),
            Station(id: "SHL", name: "South Hylton"),
            Station(id: "SJM", name: "St James"),
            Station(id: "SSS", name: "South Shields")
        ].sorted(by: { $0.name < $1.name })
    }
}