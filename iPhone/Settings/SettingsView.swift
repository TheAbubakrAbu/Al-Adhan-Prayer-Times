import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    
    @State private var showingCredits = false

    var body: some View {
        NavigationView {
            List {
                #if !os(watchOS)
                Section(header: Text("NOTIFICATIONS")) {
                    NavigationLink(destination: NotificationView()) {
                        Label("Notification Settings", systemImage: "bell.badge")
                    }
                    .accentColor(settings.accentColor.color)
                }
                #endif
                
                Section(header: Text("AL-ADHAN")) {
                    NavigationLink(destination: SettingsPrayerView(showNotifications: false)) {
                        Label("Prayer Settings", systemImage: "safari")
                    }
                    .accentColor(settings.accentColor.color)
                }
                
                #if !os(watchOS)
                Section(header: Text("MANUAL OFFSETS")) {
                    NavigationLink(destination: {
                        List {
                            Section(header: Text("HIJRI OFFSET")) {
                                Stepper("Hijri Offset: \(settings.hijriOffset) days", value: $settings.hijriOffset, in: -3...3)
                                    .font(.subheadline)
                                
                                if let hijriDate = settings.hijriDate {
                                    Text("English: \(hijriDate.english)")
                                        .foregroundColor(settings.accentColor.color)
                                        .font(.subheadline)
                                    
                                    Text("Arabic: \(hijriDate.arabic)")
                                        .foregroundColor(settings.accentColor.color)
                                        .font(.subheadline)
                                }
                            }
                            .onAppear {
                                settings.fetchPrayerTimes()
                            }
                            
                            PrayerOffsetsView()
                        }
                        #if !os(watchOS)
                        .applyConditionalListStyle(defaultView: true)
                        #endif
                        .navigationTitle("Manual Offset Settings")
                        .navigationBarTitleDisplayMode(.inline)
                    }) {
                        Label("Manual Offset Settings", systemImage: "slider.horizontal.3")
                    }
                    .accentColor(settings.accentColor.color)
                }
                #endif
                
                Section(header: Text("APPEARANCE")) {
                    SettingsAppearanceView()
                }
                .accentColor(settings.accentColor.color)
                
                Section(header: Text("CREDITS")) {
                    Text("Made by Abubakr Elmallah, who was a 17-year-old high school student when this app was made.\n\nSpecial thanks to my parents and to Mr. Joe Silvey, my English teacher and Muslim Student Association Advisor.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    #if !os(watchOS)
                    Button(action: {
                        settings.hapticFeedback()
                        
                        showingCredits = true
                    }) {
                        Text("View Credits")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                            .multilineTextAlignment(.center)
                    }
                    .sheet(isPresented: $showingCredits) {
                        NavigationView {
                            VStack {
                                Text("Credits")
                                    .foregroundColor(settings.accentColor.color)
                                    .font(.title)
                                    .padding(.top, 20)
                                    .padding(.bottom, 4)
                                    .padding(.horizontal)
                                
                                CreditsView()
                                
                                Button(action: {
                                    settings.hapticFeedback()
                                    
                                    showingCredits = false
                                }) {
                                    Text("Done")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(settings.accentColor.color)
                                        .foregroundColor(.primary)
                                        .cornerRadius(10)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    #endif
                    
                    HStack {
                        Text("Contact me at: ")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        
                        Text("ammelmallah@icloud.com")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, -4)
                    }
                    #if !os(watchOS)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = "ammelmallah@icloud.com"
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Email")
                            }
                        }
                    }
                    #endif
                }
            }
            .navigationTitle("Settings")
            #if !os(watchOS)
            .applyConditionalListStyle(defaultView: true)
            #endif
        }
        .navigationViewStyle(.stack)
    }
}

struct NotificationView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        List {
            PrayerSettingsSection(prayerName: "Fajr", preNotificationTime: $settings.preNotificationFajr, isNotificationOn: $settings.notificationFajr)
            PrayerSettingsSection(prayerName: "Shurooq", preNotificationTime: $settings.preNotificationSunrise, isNotificationOn: $settings.notificationSunrise)
            PrayerSettingsSection(prayerName: "Dhuhr", preNotificationTime: $settings.preNotificationDhuhr, isNotificationOn: $settings.notificationDhuhr)
            PrayerSettingsSection(prayerName: "Asr", preNotificationTime: $settings.preNotificationAsr, isNotificationOn: $settings.notificationAsr)
            PrayerSettingsSection(prayerName: "Maghrib", preNotificationTime: $settings.preNotificationMaghrib, isNotificationOn: $settings.notificationMaghrib)
            PrayerSettingsSection(prayerName: "Isha", preNotificationTime: $settings.preNotificationIsha, isNotificationOn: $settings.notificationIsha)
        }
        #if !os(watchOS)
        .applyConditionalListStyle(defaultView: true)
        #endif
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

let calculationOptions: [(String, String)] = [
    ("Muslim World League", "Muslim World League"),
    ("Moonsight Committee", "Moonsight Committee"),
    ("Umm Al-Qura", "Umm Al-Qura"),
    ("Egypt", "Egypt"),
    ("Dubai", "Dubai"),
    ("Kuwait", "Kuwait"),
    ("Qatar", "Qatar"),
    ("Turkey", "Turkey"),
    ("Tehran", "Tehran"),
    ("Karachi", "Karachi"),
    ("Singapore", "Singapore"),
    ("North America", "North America")
]

struct PrayerSettingsSection: View {
    @EnvironmentObject var settings: Settings
    
    let prayerName: String
    
    @Binding var preNotificationTime: Int
    @Binding var isNotificationOn: Bool
    
    @State private var isPrenotificationOn : Bool = false

    var body: some View {
        Section(header: Text(prayerName.uppercased())) {
            Toggle("Notification", isOn: $isNotificationOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.color)
            
            if isNotificationOn {
                Stepper(value: $preNotificationTime.animation(.easeInOut), in: 0...30, step: 5) {
                    Text("Prenotification Time:")
                        .font(.subheadline)
                    
                    Text("\(preNotificationTime) minute\(preNotificationTime != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(settings.accentColor.color)
                }
            }
        }
    }
}

struct SettingsPrayerView: View {
    @EnvironmentObject var settings: Settings
    
    @State private var showingMap = false
    
    @State private var showAlert: AlertType?
    enum AlertType: Identifiable {
        case travelTurnOnAutomatic, travelTurnOffAutomatic

        var id: Int {
            switch self {
            case .travelTurnOnAutomatic: return 1
            case .travelTurnOffAutomatic: return 2
            }
        }
    }
    
    @State var showNotifications: Bool
    
    var body: some View {
        List {
            #if !os(watchOS)
            if showNotifications {
                Section(header: Text("NOTIFICATIONS")) {
                    NavigationLink(destination: NotificationView()) {
                        Label("Notification Settings", systemImage: "bell.badge")
                    }
                }
            }
            #endif
            
            Section(header: Text("PRAYER CALCULATION")) {
                VStack(alignment: .leading) {
                    Picker("Calculation", selection: $settings.prayerCalculation.animation(.easeInOut)) {
                        ForEach(calculationOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                    
                    Text("The different calculation methods calculate Fajr and Isha differently.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
                
                VStack(alignment: .leading) {
                    Toggle("Use Hanafi Calculation for Asr", isOn: $settings.hanafiMadhab.animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.color)
                    
                    Text("The Hanafi madhab uses later calculations for Asr.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
            }
            
            Section(header: Text("TRAVELING MODE")) {
                #if !os(watchOS)
                Button(action: {
                    settings.hapticFeedback()
                    
                    showingMap = true
                }) {
                    HStack {
                        Text("Set Home City")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                        if !(settings.homeLocation?.city.isEmpty ?? true) {
                            Spacer()
                            Text(settings.homeLocation?.city ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $showingMap) {
                    MapView(showingMap: $showingMap)
                        .environmentObject(settings)
                }
                
                Toggle("Traveling Mode Turns on Automatically", isOn: $settings.travelAutomatic.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.color)
                #endif
                
                VStack(alignment: .leading) {
                    #if !os(watchOS)
                    Toggle("Traveling Mode", isOn: $settings.travelingMode.animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.color)
                        .disabled(settings.travelAutomatic)
                    
                    Text("If you are traveling more than 48 mi (77.25 km), then it is obligatory to pray Qasr, where you combine Dhuhr and Asr (2 rakahs each) and Maghrib and Isha (3 and 2 rakahs). Allah said in the Quran, “And when you (Muslims) travel in the land, there is no sin on you if you shorten As-Salah (the prayer)” [Al-Quran, An-Nisa, 4:101]. \(settings.travelAutomatic ? "This feature turns on and off automatically, but you can also control it manually in settings." : "You can control traveling mode manually in settings.")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                    #else
                    Toggle("Traveling Mode", isOn: $settings.travelingMode.animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.color)
                    #endif
                }
            }
            
            #if !os(watchOS)
            PrayerOffsetsView()
            #endif
        }
        #if !os(watchOS)
        .applyConditionalListStyle(defaultView: true)
        #endif
        .navigationTitle("Al-Adhan Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.homeLocation) { _ in
            settings.fetchPrayerTimes()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if settings.travelTurnOnAutomatic {
                    showAlert = .travelTurnOnAutomatic
                } else if settings.travelTurnOffAutomatic {
                    showAlert = .travelTurnOffAutomatic
                }
            }
        }
        .onChange(of: settings.travelAutomatic) { newValue in
            if newValue {
                settings.fetchPrayerTimes()
                
                if settings.homeLocation == nil {
                    withAnimation {
                        settings.travelingMode = false
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if settings.travelTurnOnAutomatic {
                            showAlert = .travelTurnOnAutomatic
                        } else if settings.travelTurnOffAutomatic {
                            showAlert = .travelTurnOffAutomatic
                        }
                    }
                }
            }
        }
        .confirmationDialog("", isPresented: Binding(
            get: { showAlert != nil },
            set: { if !$0 { showAlert = nil } }
        ), titleVisibility: .visible) {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Button("Override: Turn Off Traveling Mode", role: .destructive) {
                    withAnimation {
                        settings.travelingMode = false
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Keep Traveling Mode On", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }
                
            case .travelTurnOffAutomatic:
                Button("Override: Keep Traveling Mode On", role: .destructive) {
                    withAnimation {
                        settings.travelingMode = true
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Turn Off Traveling Mode", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }
                
            case .none:
                EmptyView()
            }
        } message: {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Text("Al-Adhan has automatically detected that you are traveling, so your prayers will be shortened.")
            case .travelTurnOffAutomatic:
                Text("Al-Adhan has automatically detected that you are no longer traveling, so your prayers will not be shortened.")
            case .none:
                EmptyView()
            }
        }
    }
}

struct SettingsAppearanceView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        #if !os(watchOS)
        Picker("Color Theme", selection: $settings.colorSchemeString.animation(.easeInOut)) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
        .font(.subheadline)
        .pickerStyle(SegmentedPickerStyle())
        #endif
        
        VStack(alignment: .leading) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(accentColors, id: \.self) { accentColor in
                    Circle()
                        .fill(accentColor.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(settings.accentColor == accentColor ? Color.primary : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            settings.hapticFeedback()
                            
                            withAnimation {
                                settings.accentColor = accentColor
                            }
                        }
                }
            }
            .padding(.vertical)
            
            #if !os(watchOS)
            Text("Anas ibn Malik (may Allah be pleased with him) said, “The most beloved of colors to the Messenger of Allah (peace be upon him) was green.”")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
            #endif
        }
        
        #if !os(watchOS)
        VStack(alignment: .leading) {
            Toggle("Default List View", isOn: $settings.defaultView.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.color)
            
            Text("The default list view is the standard interface found in many of Apple's first party apps, including Notes. This setting only applies to the main screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        }
        #endif
        
        VStack(alignment: .leading) {
            Toggle("Haptic Feedback", isOn: $settings.hapticOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.color)
        }
    }
}

struct PrayerOffsetsView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Section(header: Text("PRAYER OFFSETS")) {
            Stepper(value: $settings.offsetFajr, in: -10...10) {
                HStack {
                    Text("Fajr")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetFajr) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetSunrise, in: -10...10) {
                HStack {
                    Text("Sunrise")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetSunrise) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetDhuhr, in: -10...10) {
                HStack {
                    Text("Dhuhr")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetDhuhr) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetAsr, in: -10...10) {
                HStack {
                    Text("Asr")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetAsr) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetMaghrib, in: -10...10) {
                HStack {
                    Text("Maghrib")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetMaghrib) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetIsha, in: -10...10) {
                HStack {
                    Text("Isha")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetIsha) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetDhurhAsr, in: -10...10) {
                HStack {
                    Text("Combined Traveling\nDhuhr and Asr")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetDhurhAsr) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Stepper(value: $settings.offsetMaghribIsha, in: -10...10) {
                HStack {
                    Text("Combined Traveling\nMaghrib and Isha")
                        .foregroundColor(settings.accentColor.color)
                    Spacer()
                    Text("\(settings.offsetMaghribIsha) min")
                        .foregroundColor(.primary)
                }
            }
            .font(.subheadline)
            
            Text("Use these offsets to shift the calculated prayer times earlier or later. Negative values move the time earlier, positive values move it later.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        }
    }
}
