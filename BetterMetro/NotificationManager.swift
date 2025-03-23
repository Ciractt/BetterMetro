//
//  NotificationManager.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

// NotificationManager.swift

// NotificationManager.swift

import Foundation
import UserNotifications
import SwiftUI
import BackgroundTasks

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    private let disruptionService = DisruptionService()
    private var previousDisruptions: [Disruption] = []
    
    // Task identifier for background refresh
    private let backgroundTaskIdentifier = "com.bettermetro.refreshDisruptions"
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // Register for notifications and background refresh
    func registerForServices() {
        requestNotificationAuthorization()
        registerBackgroundTask()
    }
    
    // Request notification authorization from the user
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.scheduleBackgroundRefresh()
                }
            }
            
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
        }
    }
    
    // Check current authorization status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // Register background task for periodically checking disruptions
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }
    
    // Schedule background refresh task
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
    
    // Handle the background task
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        // Schedule the next background task
        scheduleBackgroundRefresh()
        
        // Create a task expiration handler
        task.expirationHandler = {
            // Cancel any ongoing work if the task is about to expire
            task.setTaskCompleted(success: false)
        }
        
        // Check for new disruptions
        checkForNewDisruptions { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    // Fetch the latest disruptions and compare with previous ones
    func checkForNewDisruptions(completion: @escaping (Bool) -> Void = { _ in }) {
        // Manual fetch and processing
        let urlComponents = URLComponents(string: "https://ken.nebulalabs.cc/disruption/active/")
        guard let url = urlComponents?.url else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
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
                let disruptions = try JSONDecoder().decode([Disruption].self, from: data)
                DispatchQueue.main.async {
                    self.processNewDisruptions(disruptions)
                    completion(true)
                }
            } catch {
                print("Error decoding data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Process new disruptions and send notifications for changes
    private func processNewDisruptions(_ currentDisruptions: [Disruption]) {
        // Filter out the "for_information_only" disruptions for notifications
        let notificationWorthy = currentDisruptions.filter { $0.priorityLevel != "for_information_only" }
        
        // Get previous notification worthy disruptions
        let previousNotificationWorthy = previousDisruptions.filter { $0.priorityLevel != "for_information_only" }
        
        // Find new disruptions (ones that weren't in the previous list)
        let newDisruptions = notificationWorthy.filter { current in
            !previousNotificationWorthy.contains { $0.id == current.id }
        }
        
        // Send notifications for new disruptions
        for disruption in newDisruptions {
            sendDisruptionNotification(disruption)
        }
        
        // Update the previous disruptions list
        self.previousDisruptions = currentDisruptions
    }
    
    // Send a notification for a disruption
    private func sendDisruptionNotification(_ disruption: Disruption) {
        // Don't notify for information-only disruptions
        if disruption.priorityLevel == "for_information_only" {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Metro Status Update"
        content.subtitle = disruption.title
        content.body = disruption.content
        content.sound = .default
        
        // Add useful information to the notification
        content.userInfo = [
            "disruptionId": disruption.id,
            "priorityLevel": disruption.priorityLevel
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
            }
        }
    }
    
    // Manually trigger a check for new disruptions (called when app becomes active)
    func refreshDisruptionsFromForeground() {
        checkForNewDisruptions()
    }
    
    // For testing purposes - simulate a notification
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.subtitle = "Metro Status Update"
        content.body = "This is a test notification to confirm push notifications are working correctly."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle if user tapped on the notification
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Open the status view or details for this disruption
            if let disruptionId = userInfo["disruptionId"] as? Int {
                // You can use this ID to navigate to the detail view
                // This would require a global navigation state to be implemented
                print("User tapped on notification for disruption: \(disruptionId)")
            }
        }
        
        completionHandler()
    }
}
