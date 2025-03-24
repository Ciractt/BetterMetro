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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        // Register for background refresh tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.bettermetro.refreshDisruptions",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Set the APNS token for Firebase
        Messaging.messaging().apnsToken = deviceToken
        
        // Convert token to string for logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNS Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
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
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
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
            
            // Send notification for any observers
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
}