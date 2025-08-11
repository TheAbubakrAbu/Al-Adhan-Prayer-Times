import AppIntents

@available(iOS 16.0, watchOS 9.0, *)
struct AppShortcutsRoot: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhenIsPrayerIntent(),
            phrases: [
                "When is \(\.$prayer) in \(.applicationName)",
                "What time is \(\.$prayer) in \(.applicationName)",
                "What is the time for \(\.$prayer) in \(.applicationName)",
                "When does \(\.$prayer) start in \(.applicationName)",
                "Time for \(\.$prayer) in \(.applicationName)",
                "Prayer time for \(\.$prayer) in \(.applicationName)",
                "When is \(\.$prayer) prayer in \(.applicationName)",
                "What time is \(\.$prayer) prayer in \(.applicationName)",
                "وقت \(\.$prayer) في \(.applicationName)",
                "متى \(\.$prayer) في \(.applicationName)",
                "ما وقت \(\.$prayer) في \(.applicationName)",
            ],
            shortTitle: "When is Prayer",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: CurrentPrayerIntent(),
            phrases: [
                "What is the current prayer in \(.applicationName)",
                "Current prayer in \(.applicationName)",
                "What prayer is it now in \(.applicationName)",
                "Which prayer is now in \(.applicationName)",
                "What prayer time is it in \(.applicationName)",
                "ما هي الصلاة الحالية في \(.applicationName)",
                "ما هي الصلاة الآن في \(.applicationName)",
                "ما الصلاة الآن في \(.applicationName)",
            ],
            shortTitle: "Current Prayer",
            systemImageName: "clock.badge.checkmark"
        )

        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "What is the next prayer in \(.applicationName)",
                "When is the next prayer in \(.applicationName)",
                "What is the next prayer time in \(.applicationName)",
                "When is the next prayer time in \(.applicationName)",
                "Next prayer in \(.applicationName)",
                "Next prayer time in \(.applicationName)",
                "Time of the next prayer in \(.applicationName)",
                "Which prayer is next in \(.applicationName)",
                "ما هي الصلاة القادمة في \(.applicationName)",
                "متى الصلاة القادمة في \(.applicationName)",
                "ما وقت الصلاة القادمة في \(.applicationName)",
                "وقت الصلاة القادمة في \(.applicationName)",
            ],
            shortTitle: "Next Prayer",
            systemImageName: "forward.end"
        )
    }
}

