import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct PrayerTimesApp: App {
    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel()
    
    @State private var isLaunching = true
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    LaunchScreen(isLaunching: $isLaunching)
                } else if settings.firstLaunch {
                    SplashScreen()
                } else {
                    PrayerView()
                }
            }
            .environmentObject(settings)
            .environmentObject(namesData)
            .accentColor(settings.accentColor.color)
            .preferredColorScheme(settings.colorScheme)
            .transition(.opacity)
            .onAppear {
                withAnimation {
                    settings.fetchPrayerTimes()
                }
            }
        }
        .onChange(of: settings.accentColor) { _ in
            sendMessageToWatch()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: settings.prayerCalculation) { _ in
            settings.fetchPrayerTimes(force: true)
            sendMessageToWatch()
        }
        .onChange(of: settings.hanafiMadhab) { _ in
            settings.fetchPrayerTimes(force: true)
            sendMessageToWatch()
        }
        .onChange(of: settings.travelingMode) { _ in
            settings.fetchPrayerTimes(force: true)
            sendMessageToWatch()
        }
        .onChange(of: settings.hijriOffset) { _ in
            settings.updateDates()
            sendMessageToWatch()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func sendMessageToWatch() {
        guard WCSession.default.isPaired else {
            print("No Apple Watch is paired")
            return
        }
        
        let settingsData = settings.dictionaryRepresentation()
        let message = ["settings": settingsData]

        if WCSession.default.isReachable {
            print("Watch is reachable. Sending message to watch: \(message)")

            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message to watch: \(error.localizedDescription)")
            }
        } else {
            print("Watch is not reachable. Transferring user info to watch: \(message)")
            WCSession.default.transferUserInfo(message)
        }
    }
}
