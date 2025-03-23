//
//  BetterMetroApp.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// BetterMetroApp.swift

import SwiftUI
import BackgroundTasks

@main
struct BetterMetroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    // Request notification permissions when app first launches
                    notificationManager.registerForServices()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh disruptions when app becomes active
                    notificationManager.refreshDisruptionsFromForeground()
                }
        }
    }
}

// App Delegate to handle background tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for background tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.bettermetro.refreshDisruptions", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert token to string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // In a real app, you would send this token to your server
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Forward to the notification manager
        NotificationManager.shared.checkForNewDisruptions { success in
            task.setTaskCompleted(success: success)
        }
        
        // Schedule next refresh
        NotificationManager.shared.scheduleBackgroundRefresh()
    }
}
