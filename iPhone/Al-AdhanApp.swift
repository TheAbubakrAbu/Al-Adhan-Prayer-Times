import SwiftUI
import WidgetKit
import StoreKit

@main
struct AlAdhanApp: App {
    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("firstLaunchSheet") var firstLaunchSheet: Bool = true
    @State var showAdhanSheet: Bool = false
    
    @State private var isLaunching = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    LaunchScreen(isLaunching: $isLaunching)
                } else if settings.firstLaunch {
                    SplashScreen()
                } else {
                    TabView {
                        AdhanView()
                            .tabItem {
                                Image(systemName: "safari")
                                Text("Adhan")
                            }
                        
                        OtherView()
                            .tabItem {
                                Image(systemName: "moon.stars")
                                Text("Tools")
                            }
                        
                        SettingsView()
                            .tabItem {
                                Image(systemName: "gearshape")
                                Text("Settings")
                            }
                    }
                    .onAppear {
                        if firstLaunchSheet {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation {
                                    showAdhanSheet = true
                                }
                            }
                        }
                    }
                    .sheet(
                        isPresented: $showAdhanSheet,
                        onDismiss: {
                            firstLaunchSheet = false
                        }) {
                        AdhanSetupSheet()
                            .environmentObject(settings)
                            .accentColor(settings.accentColor.color)
                            .tint(settings.accentColor.color)
                            .preferredColorScheme(settings.colorScheme)
                            .transition(.opacity)
                    }
                }
            }
            //.statusBarHidden(true)
            .environmentObject(settings)
            .environmentObject(namesData)
            .accentColor(settings.accentColor.color)
            .tint(settings.accentColor.color)
            .preferredColorScheme(settings.colorScheme)
            .transition(.opacity)
            .animation(.easeInOut, value: isLaunching)
            .animation(.easeInOut, value: settings.firstLaunch)
            .appReviewPrompt()
            .onAppear {
                withAnimation {
                    settings.fetchPrayerTimes()
                }
            }
        }
        .onChange(of: settings.accentColor) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: settings.prayerCalculation) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.hanafiMadhab) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.travelingMode) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.hijriOffset) { _ in
            settings.updateDates()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
