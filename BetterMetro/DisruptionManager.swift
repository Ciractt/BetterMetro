//
//  DisruptionManager.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 24/03/2025.
//


// DisruptionManager.swift

import Foundation
import UIKit
import UserNotifications
import BackgroundTasks
import FirebaseMessaging

class DisruptionManager: NSObject {
    static let shared = DisruptionManager()
    
    var fcmToken: String?
    private(set) var isSubscribedToTopics = false
    private var previousDisruptions: [Disruption] = []
    
    // Background refresh task identifier
    private let backgroundTaskIdentifier = "com.bettermetro.refreshDisruptions"
    
    // Topic identifiers
    private let topics = [
        "metro_disruptions",
        "green_line",
        "yellow_line"
    ]
    
    override init() {
        super.init()
        loadFCMToken()
    }
    
    // MARK: - Token Management
    
    private func loadFCMToken() {
        fcmToken = UserDefaults.standard.string(forKey: "fcmToken")
        
        // Check if we need to subscribe to topics
        if let token = fcmToken, !isSubscribedToTopics {
            subscribeToTopics()
        }
    }
    
    // MARK: - Topic Subscription
    
    func subscribeToTopics() {
        guard let _ = fcmToken else {
            print("Cannot subscribe to topics: FCM token is missing")
            return
        }
        
        for topic in topics {
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    print("Error subscribing to \(topic): \(error.localizedDescription)")
                } else {
                    print("Successfully subscribed to \(topic)")
                }
            }
        }
        
        isSubscribedToTopics = true
    }
    
    func unsubscribeFromTopics() {
        guard let _ = fcmToken else { return }
        
        for topic in topics {
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error = error {
                    print("Error unsubscribing from \(topic): \(error.localizedDescription)")
                } else {
                    print("Successfully unsubscribed from \(topic)")
                }
            }
        }
        
        isSubscribedToTopics = false
    }
    
    // MARK: - Background Tasks
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // Set the earliest begin date to 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled successfully")
        } catch {
            print("Could not schedule background task: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Disruption Handling
    
    func checkForNewDisruptions(completion: @escaping (Bool) -> Void = { _ in }) {
        // Construct URL with parameters
        var components = URLComponents(string: "https://ken.nebulalabs.cc/disruption/active/")
        components?.queryItems = [
            URLQueryItem(name: "facilities", value: "train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting"),
            URLQueryItem(name: "routes", value: "green_line,yellow_line"),
            URLQueryItem(name: "stations", value: "airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay"),
            URLQueryItem(name: "priority_levels", value: "service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other")
        ]
        
        guard let url = components?.url else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching disruptions: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                let currentDisruptions = try JSONDecoder().decode([Disruption].self, from: data)
                
                DispatchQueue.main.async {
                    self.processNewDisruptions(currentDisruptions)
                    completion(true)
                }
            } catch {
                print("Error decoding disruptions: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        
        task.resume()
    }
    
    private func processNewDisruptions(_ currentDisruptions: [Disruption]) {
        // Filter out the "for_information_only" disruptions for notifications
        let notificationWorthy = currentDisruptions.filter { $0.priorityLevel != "for_information_only" }
        
        // Get previous notification worthy disruptions
        let previousNotificationWorthy = previousDisruptions.filter { $0.priorityLevel != "for_information_only" }
        
        // Find new disruptions (ones that weren't in the previous list)
        let newDisruptions = notificationWorthy.filter { current in
            !previousNotificationWorthy.contains { $0.id == current.id }
        }
        
        // Send local notifications for new disruptions
        for disruption in newDisruptions {
            sendLocalNotification(for: disruption)
        }
        
        // Update the previous disruptions list
        self.previousDisruptions = currentDisruptions
    }
    
    private func sendLocalNotification(for disruption: Disruption) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Metro Status Update"
        content.subtitle = disruption.title
        content.body = disruption.content
        content.sound = .default
        
        // Add useful information to the notification
        content.userInfo = [
            "disruptionId": String(disruption.id),
            "priorityLevel": disruption.priorityLevel,
            "impactedRoutes": disruption.impactedRoutes
        ]
        
        // Add category identifier for actionable notifications if needed
        content.categoryIdentifier = "DISRUPTION"
        
        // Create a request with immediate trigger
        let request = UNNotificationRequest(
            identifier: "disruption-\(disruption.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Successfully scheduled notification for disruption \(disruption.id)")
            }
        }
    }
    
    // MARK: - Manual Refresh
    
    func refreshDisruptionsFromForeground() {
        checkForNewDisruptions()
    }
}