# BetterMetro

An unofficial iOS app for the Tyne and Wear Metro, providing real-time information, interactive maps, and service updates.

![BetterMetro App Banner](app_banner.png)

## Overview

BetterMetro is a community-developed iOS application designed to improve the experience of using the Tyne and Wear Metro system. Built with SwiftUI for iOS 18, the app offers a clean, modern interface with features focused on providing accurate, timely information to Metro passengers.

**Disclaimer:** This app is not affiliated with, endorsed by, or officially connected to Nexus or the Tyne and Wear Metro operators. It is an independent community project.

## Features

- **Full-screen Interactive Map**: Explore the entire Metro system with an embedded interactive map
- **Real-time Train Information**: Get up-to-date information on train arrivals and departures
- **Line Status Updates**: Receive notifications about service disruptions and line statuses
- **Station Details**: Access detailed information about stations, platforms, and facilities
- **Push Notifications**: Opt in to receive important service updates and disruption alerts
- **Modern UI**: Clean, intuitive interface designed for iOS 18 with a floating tab navigation system

## Screenshots

<div style="display: flex; justify-content: space-between;">
  <img src="screenshots/map_view.png" width="200" alt="Map View">
  <img src="screenshots/status_view.png" width="200" alt="Status View">
  <img src="screenshots/disruption_detail.png" width="200" alt="Disruption Detail">
  <img src="screenshots/settings_view.png" width="200" alt="Settings View">
</div>

## Development

### Requirements

- Xcode 16.2 or later
- iOS 18 or later
- Swift 5.9+

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/BetterMetro.git
   cd BetterMetro
   ```

2. Open the project in Xcode:
   ```bash
   open BetterMetro.xcodeproj
   ```

3. Build and run the app on your simulator or device.

### Project Structure

- **MainView.swift**: Main container view with full-screen map and floating tab bar
- **DisruptionModels.swift**: Data models and service for fetching Metro disruption data
- **NotificationManager.swift**: Handles push notifications for service updates
- **StatusView.swift**: Displays line status and disruption information
- **SettingsView.swift**: User preferences and app information

### APIs Used

The app uses the following public API endpoints:

- Station information: `https://metro-rti.nexus.org.uk/api/stations`
- Platform information: `https://metro-rti.nexus.org.uk/api/stations/platforms`
- Real-time train information: `https://metro-rti.nexus.org.uk/api/times/{stationCode}/{platformNumber}`
- Service disruptions: `https://ken.nebulalabs.cc/disruption/active/`

## Contribution

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Privacy

BetterMetro respects user privacy:
- Location data is used only for app functionality and is not stored remotely
- No user accounts or profiles are maintained
- No analytics tracking is implemented
- No data is shared with third parties

For more details, please see our [Privacy Policy](PRIVACY.md).

## Acknowledgments

- Tyne and Wear Metro for providing public API access to Metro information
- OpenStreetMap for the embedded map system
- The SwiftUI community for inspiration and examples
- All contributors who have helped improve this app
