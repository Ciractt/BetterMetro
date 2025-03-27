//
//  MainView.swift
//  BetterMetro
//
//  Created by Sam Maurício-Muir on 23/03/2025.
//

// MainView.swift

import SwiftUI
import WebKit

struct MainView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content based on selected tab
            Group {
                if selectedTab == 0 {
                    MapContent()
                } else if selectedTab == 1 {
                    StationsView()
                } else if selectedTab == 2 {
                    JourneyPlannerView()
                } else if selectedTab == 3 {
                    StatusView()
                } else if selectedTab == 4 {
                    SettingsView()
                }
            }
            .ignoresSafeArea()
            
            // Floating tab bar
            MainFloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }
}

struct MapContent: View {
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            MainWebViewContainer(url: URL(string: "https://metro-rti.nexus.org.uk/MapEmbedded/")!, isLoading: $isLoading)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
            }
        }
    }
}

struct MainFloatingTabBar: View {
    @Binding var selectedTab: Int
    
    private let items = [
        ("Map", "map.fill"),
        ("Pop Card", "train.side.front.car"),
        ("Journey", "arrow.triangle.swap"),
        ("Status", "info.circle.fill"),
        ("Settings", "gear")
    ]
    
    var body: some View {
        HStack(spacing: 25) {
            ForEach(0..<items.count, id: \.self) { index in
                let (title, icon) = items[index]
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(selectedTab == index ? .blue : .gray)
                .animation(.easeInOut, value: selectedTab)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
}

// WebView Container
struct MainWebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MainWebViewContainer
        
        init(_ parent: MainWebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Remove scrollbars, borders, and zoom controls
            let script = """
            // Clean up general styling
            document.body.style.margin = '0';
            document.body.style.padding = '0';
            document.documentElement.style.overflow = 'hidden';
            
            // More selective styling to maintain interactivity
            // Only hide scrollbars and borders, don't affect pointer events
            var stylesheets = document.styleSheets;
            var stylesheet;
            
            // Create a new stylesheet if necessary
            if (stylesheets.length > 0) {
                stylesheet = stylesheets[0];
            } else {
                var style = document.createElement('style');
                document.head.appendChild(style);
                stylesheet = style.sheet;
            }
            
            // Add specific styling rules
            stylesheet.insertRule('.ol-zoom { display: none !important; }', 0);
            stylesheet.insertRule('.ol-attribution { display: none !important; }', 0);
            stylesheet.insertRule('*::-webkit-scrollbar { display: none !important; }', 0);
            
            // Fix borders without affecting click events
            var mapElements = document.querySelectorAll('.ol-viewport, .ol-layer');
            for (var i = 0; i < mapElements.length; i++) {
                mapElements[i].style.border = 'none';
            }
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("WebView did fail: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("WebView did fail provisional navigation: \(error.localizedDescription)")
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
