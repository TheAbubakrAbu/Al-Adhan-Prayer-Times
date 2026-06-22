import SwiftUI
import WidgetKit

@main
struct AlAdhanApp: App {
    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLaunching = true

    init() {
        // Activate WatchConnectivity so settings sync (and watch app-installed detection) work both ways.
        _ = WatchConnectivityManager.shared
    }

    private enum RootStage: Equatable {
        case launch
        case splash
        case main
    }

    private var rootStage: RootStage {
        if isLaunching {
            return .launch
        }
        return settings.firstLaunch ? .splash : .main
    }

    private var rootTransitionAnimation: Animation {
        .easeInOut(duration: 0.42)
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(settings)
                .environmentObject(namesData)
                .accentColor(settings.accentColor.color)
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.colorScheme)
                .appReviewPrompt()
                .onAppear(perform: refreshPrayerTimes)
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

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            if rootStage == .launch {
                LaunchScreen(isLaunching: $isLaunching)
                    .zIndex(3)
                    .transition(.opacity)
            }

            if rootStage == .splash {
                SplashScreen()
                    .zIndex(2)
                    .transition(.opacity)
            }

            if rootStage == .main {
                MainTabView()
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .animation(rootTransitionAnimation, value: rootStage)
    }

    private func refreshPrayerTimes() {
        withAnimation {
            settings.fetchPrayerTimes()
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            TabView {
                Tab("Adhan", systemImage: "mecca") {
                    AdhanView()
                }

                Tab("Islam", systemImage: "moon.stars") {
                    IslamView()
                }

                Tab("Settings", systemImage: "gearshape") {
                    SettingsView()
                }
            }
        } else {
            TabView {
                AdhanView()
                    .tabItem {
                        Image(systemName: "safari")
                        Text("Adhan")
                    }

                IslamView()
                    .tabItem {
                        Image(systemName: "moon.stars")
                        Text("Islam")
                    }

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
            }
        }
    }
}

