//
//  SettingsView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//


// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
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
                            Toggle("Enable Push Notifications", isOn: $notificationManager.isAuthorized)
                                .onChange(of: notificationManager.isAuthorized) { oldValue, newValue in
                                    if newValue {
                                        notificationManager.requestNotificationAuthorization()
                                    } else {
                                        // Redirect to system settings if they want to disable
                                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                                            return
                                        }
                                        UIApplication.shared.open(settingsURL)
                                    }
                                }
                        }
                        
                        // App information section
                        SettingsSection(title: "About", icon: "info.circle.fill") {
                            InfoRow(title: "Version", value: "0.1.2")
                            InfoRow(title: "Build", value: "1")
                            InfoRow(title: "Developer", value: "BetterMetro")
                        }
                        
                        // Support section
                        SettingsSection(title: "Support", icon: "questionmark.circle.fill") {
                            NavigationLink(destination: Text("Privacy Policy")) {
                                SettingsRow(title: "Privacy Policy")
                            }
                            
                            NavigationLink(destination: Text("Terms of Service")) {
                                SettingsRow(title: "Terms of Service")
                            }
                            
                            Link(destination: URL(string: "https://www.nexus.org.uk/metro")!) {
                                SettingsRow(title: "Nexus Metro Website")
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding(.bottom, 90) // Make room for floating tab bar
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
