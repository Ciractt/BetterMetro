//
//  BetterMetroApp.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// BetterMetroApp.swift

import SwiftUI
import BackgroundTasks
import Firebase

@main
struct BetterMetroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    // Request notification permissions when app first launches
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if granted {
                            print("Notification authorization granted")
                        } else if let error = error {
                            print("Failed to request notification authorization: \(error.localizedDescription)")
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh disruptions when app becomes active
                    DisruptionManager.shared.refreshDisruptionsFromForeground()
                }
                // Listen for notification to open disruption detail
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenDisruptionDetail"))) { notification in
                    if let disruptionId = notification.userInfo?["disruptionId"] as? String,
                       let id = Int(disruptionId) {
                        // Handle navigation to disruption detail
                        // This would need to be connected to your navigation state
                        print("Should navigate to disruption ID: \(id)")
                    }
                }
        }
    }
}
