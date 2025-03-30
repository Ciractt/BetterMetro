//
//  AppDelegate.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 24/03/2025.
//
// AppDelegate.swift

import UIKit
import BackgroundTasks
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    // Flag to track if Firebase has been configured
    private var hasConfiguredFirebase = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification permissions first, but DON'T configure Firebase here
        requestNotificationPermission(application)
        
        // Register for background refresh tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.bettermetro.refreshDisruptions",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    // Request notification permission explicitly before Firebase setup
    private func requestNotificationPermission(_ application: UIApplication) {
        // Set the UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request authorization
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { granted, error in
            print("Notification authorization granted: \(granted)")
            
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
            
            // Once authorization is granted, register for remote notifications on the main thread
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // Called when APNS registration is successful
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Successfully registered for remote notifications with APNS")
        
        // Configure Firebase only after getting the APNS token
        if !hasConfiguredFirebase {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            hasConfiguredFirebase = true
            print("Firebase configured after receiving APNS token")
        }
        
        // Then set the APNS token
        Messaging.messaging().apnsToken = deviceToken
        
        // Convert token to string for logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNS Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        
        // Even if we failed to get an APNS token, we might still want to initialize Firebase
        // for other functionality but without messaging
        if !hasConfiguredFirebase {
            FirebaseApp.configure()
            hasConfiguredFirebase = true
            print("Firebase configured despite APNS registration failure")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Create a task expiration handler
        task.expirationHandler = {
            // Cancel any ongoing work if the task is about to expire
            task.setTaskCompleted(success: false)
        }
        
        // Check for disruptions
        DisruptionManager.shared.checkForNewDisruptions { success in
            // Schedule the next refresh
            DisruptionManager.shared.scheduleBackgroundRefresh()
            
            // Mark the task as completed
            task.setTaskCompleted(success: success)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Log FCM data if available
        if let messageID = userInfo["gcm.message_id"] {
            print("Message ID: \(messageID)")
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Log FCM data if available
        if let messageID = userInfo["gcm.message_id"] {
            print("Handling notification with Message ID: \(messageID)")
        }
        
        // Handle notification tap actions
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let disruptionId = userInfo["disruptionId"] as? String {
                // Notify the app to navigate to disruption details
                NotificationCenter.default.post(
                    name: Notification.Name("OpenDisruptionDetail"),
                    object: nil,
                    userInfo: ["disruptionId": disruptionId]
                )
            }
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        // Store the token in UserDefaults
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
            DisruptionManager.shared.fcmToken = token
            
            // Subscribe to topics once we have a valid FCM token
            subscribeToTopics()
            
            // Send notification for any observers
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
    
    // Subscribe to relevant topics for notifications
    private func subscribeToTopics() {
        // Subscribe to general disruptions topic
        Messaging.messaging().subscribe(toTopic: "metro_disruptions") { error in
            if let error = error {
                print("Error subscribing to metro_disruptions: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to metro_disruptions topic")
            }
        }
        
        // Subscribe to green line topic
        Messaging.messaging().subscribe(toTopic: "green_line") { error in
            if let error = error {
                print("Error subscribing to green_line: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to green_line topic")
            }
        }
        
        // Subscribe to yellow line topic
        Messaging.messaging().subscribe(toTopic: "yellow_line") { error in
            if let error = error {
                print("Error subscribing to yellow_line: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to yellow_line topic")
            }
        }
    }
}
