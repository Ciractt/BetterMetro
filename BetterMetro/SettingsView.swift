//
//  SettingsView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @State private var isNotificationsAuthorized = false
    @State private var isSubscribedToTopics = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Notifications section
                        SettingsSection(title: "Notifications", icon: "bell.fill") {
                            Toggle("Enable Notifications", isOn: $isNotificationsAuthorized)
                                .onChange(of: isNotificationsAuthorized) { oldValue, newValue in
                                    if newValue {
                                        requestNotificationPermission()
                                    } else {
                                        // Redirect to system settings if they want to disable
                                        openAppSettings()
                                    }
                                }
                            
                            Toggle("Subscribe to Metro Updates", isOn: $isSubscribedToTopics)
                                .onChange(of: isSubscribedToTopics) { oldValue, newValue in
                                    if newValue {
                                        DisruptionManager.shared.subscribeToTopics()
                                    } else {
                                        DisruptionManager.shared.unsubscribeFromTopics()
                                    }
                                }
                                .disabled(!isNotificationsAuthorized)
                        }
                        
                        // App information section
                        SettingsSection(title: "About", icon: "info.circle.fill") {
                            InfoRow(title: "Version", value: "1.0.0")
                            InfoRow(title: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            InfoRow(title: "Community Project", value: "Not affiliated with Nexus")
                        }
                        
                        // Support section
                        SettingsSection(title: "Support", icon: "questionmark.circle.fill") {
                            Button(action: {
                                // Open Privacy Policy
                                if let url = URL(string: "https://example.com/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsRow(title: "Privacy Policy")
                            }
                            
                            Button(action: {
                                // Open Nexus Metro website
                                if let url = URL(string: "https://www.nexus.org.uk/metro") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsRow(title: "Nexus Metro Website")
                            }
                            
                            Button(action: {
                                // Open GitHub repo
                                if let url = URL(string: "https://github.com/yourusername/BetterMetro") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsRow(title: "GitHub Repository")
                            }
                        }
                        
                        Text("BetterMetro is a community project and is not affiliated with, endorsed by, or connected to Nexus or the Tyne and Wear Metro operators.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }
                    .padding()
                }
            }
            .padding(.bottom, 90) // Make room for floating tab bar
        }
        .onAppear {
            checkNotificationStatus()
            isSubscribedToTopics = DisruptionManager.shared.isSubscribedToTopics
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                isNotificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                isNotificationsAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct SettingsRow: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
