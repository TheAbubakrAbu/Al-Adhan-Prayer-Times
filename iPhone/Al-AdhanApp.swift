import SwiftUI
import WidgetKit

/// Coordinates the "warm the main UI behind the launch screen, then reveal" hand-off.
///
/// The launch screen already has a quiet "hold on the logo and wait for init" phase; it now also waits for
/// `isWarm` before it plays its finale and hands off. `MainTabView` sets `isWarm` once it has built + retained
/// the heavy Quran tab and settled back on the Adhan landing tab — all behind the launch cover. Net effect: the
/// reveal happens only when everything is already built and on the right tab, so there's no tab flip and no
/// first-tap stall the user can see.
@MainActor
final class LaunchWarmup: ObservableObject {
    static let shared = LaunchWarmup()
    private init() {}

    @Published private(set) var isWarm = false

    func markWarm() { isWarm = true }

    /// Await `isWarm`, but never block the launch longer than `maxWaitNanos` (a safety cap so a failed warm can
    /// never strand the user on the launch screen).
    func waitUntilWarm(maxWaitNanos: UInt64) async {
        var waited: UInt64 = 0
        let step: UInt64 = 20_000_000
        while !isWarm && waited < maxWaitNanos {
            try? await Task.sleep(nanoseconds: step)
            waited += step
        }
    }
}

@main
struct AlAdhanApp: App {
    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLaunching = true
    // Keeps the splash mounted through its fade-out (see `rootContent`).
    @State private var splashPresented = false

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
        .easeInOut(duration: 0.5)
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
                .onAppear { settings.fetchPrayerTimes() }
                //.statusBarHidden()
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
        .onChange(of: scenePhase) { phase in
            if phase == .active { } else {
                // Send any just-made setting change before the app is suspended, so it can't be lost (and
                // can't be reverted by a stale synced value on the next launch).
                WatchConnectivityManager.shared.flushPendingSync()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            // Keep the tabs mounted from the very first frame — even while the launch/splash screen still covers
            // the screen — so the Quran tab can realize its (heavy) view tree behind that cover instead of on
            // the first visible tap. Al-Quran never lags here because Quran is its default tab and realizes
            // under the splash; mounting early gives Al-Islam the same head start while still landing the user
            // on the Adhan tab (see `MainTabView`, which sits on Quran while covered then flips to Adhan on
            // reveal). The launch/splash screens overlay on top and fade out to reveal it.
            MainTabView(isCovered: rootStage != .main)
                // Always opaque underneath the covers. The launch/splash screens are opaque and simply fade
                // themselves out (below) to reveal it — a clean single-layer dissolve, no mid-transition dip.
                .zIndex(1)

            if rootStage == .launch {
                LaunchScreen(isLaunching: $isLaunching)
                    .zIndex(3)
                    .transition(.opacity)
            }

            // The splash fades via an explicit `.opacity` (kept mounted through the fade), NOT a removal
            // `.transition`: SplashScreen wraps a NavigationView, which doesn't animate SwiftUI removal
            // transitions — it just snaps. A plain opacity animation on the hosted content works, giving the
            // splash → main hand-off a real cross-fade. It's unmounted a beat after the fade completes.
            if splashPresented {
                SplashScreen()
                    .opacity(rootStage == .splash ? 1 : 0)
                    .allowsHitTesting(rootStage == .splash)
                    .zIndex(2)
            }
        }
        .animation(rootTransitionAnimation, value: rootStage)
        // The tabs are mounted (and side-effecting views like AdhanView build) before the cover lifts; let them
        // hold user-facing prompts until we're actually on screen.
        .environment(\.appRevealed, rootStage == .main)
        .onChange(of: rootStage) { stage in
            if stage == .splash {
                splashPresented = true
            } else if splashPresented {
                // Leaving the splash: its opacity is animating to 0 above — unmount once that fade is done.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if rootStage != .splash { splashPresented = false }
                }
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var settings: Settings

    /// True while a launch/splash screen still covers the tabs (drives the under-cover warm below).
    let isCovered: Bool

    private enum AppTab: Hashable { case adhan, quran, islam, settings }

    // We land the user on Adhan, so Adhan is the initial tab and builds first. The Quran tab is realized during
    // `warmUnderCover()` — briefly selected so `TabView` builds and RETAINS its heavy view tree, then we settle
    // back on Adhan. All of this happens behind the launch cover, and the launch screen waits for it to finish
    // (see `LaunchWarmup`) before it reveals — so the user only ever sees a fully-built Adhan tab, and the first
    // tap on Quran reuses the warm tab instantly. No visible tab flip, no first-tap stall.
    @State private var selectedTab: AppTab = .adhan
    @State private var didWarm = false

    var body: some View {
        tabs
    }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Adhan", systemImage: "mecca", value: AppTab.adhan) {
                    AdhanView()
                }

                Tab("Islam", systemImage: "moon.stars", value: AppTab.islam) {
                    IslamView()
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    SettingsView()
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                AdhanView()
                    .tabItem {
                        Image(systemName: "safari")
                        Text("Adhan")
                    }
                    .tag(AppTab.adhan)

                IslamView()
                    .tabItem {
                        Image(systemName: "moon.stars")
                        Text("Islam")
                    }
                    .tag(AppTab.islam)

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(AppTab.settings)
            }
        }
    }
}
