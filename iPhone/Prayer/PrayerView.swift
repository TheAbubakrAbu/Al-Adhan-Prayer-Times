import SwiftUI

struct PrayerView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var namesData: NamesViewModel
    
    @Environment(\.scenePhase) private var scenePhase
        
    @State private var showAlert: AlertType?
    enum AlertType: Identifiable {
        case travelTurnOnAutomatic, travelTurnOffAutomatic, locationAlert, notificationAlert

        var id: Int {
            switch self {
            case .travelTurnOnAutomatic: return 1
            case .travelTurnOffAutomatic: return 2
            case .locationAlert: return 3
            case .notificationAlert: return 4
            }
        }
    }
    
    @State private var showingArabicSheet = false
    @State private var showingAdhkarSheet = false
    @State private var showingDuaSheet = false
    @State private var showingTasbihSheet = false
    @State private var showingNamesSheet = false
    @State private var showingDateSheet = false
    @State private var showingSettingsSheet = false
    
    func prayerTimeRefresh(force: Bool) {
        settings.requestNotificationAuthorization()
        settings.fetchPrayerTimes(force: force)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if settings.travelTurnOnAutomatic {
                showAlert = .travelTurnOnAutomatic
            } else if settings.travelTurnOffAutomatic {
                showAlert = .travelTurnOffAutomatic
            } else if !settings.locationNeverAskAgain && settings.showLocationAlert {
                showAlert = .locationAlert
            } else if !settings.notificationNeverAskAgain && settings.showNotificationAlert {
                showAlert = .notificationAlert
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: settings.defaultView ? Text("DATE AND LOCATION") : nil) {
                    if let hijriDate = settings.hijriDate {
                        #if !os(watchOS)
                        HStack {
                            Text(hijriDate.english)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                            
                            Text(hijriDate.arabic)
                        }
                        .font(.footnote)
                        .foregroundColor(settings.accentColor.color)
                        .contextMenu {
                            Button(action: {
                                settings.hapticFeedback()
                                
                                UIPasteboard.general.string = hijriDate.english
                            }) {
                                Text("Copy English Date")
                                Image(systemName: "doc.on.doc")
                            }
                            
                            Button(action: {
                                settings.hapticFeedback()
                                
                                UIPasteboard.general.string = hijriDate.arabic
                            }) {
                                Text("Copy Arabic Date")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        #else
                        HStack {
                            Spacer()
                            
                            Text(hijriDate.english)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .font(.footnote)
                        .foregroundColor(settings.accentColor.color)
                        #endif
                    }
                    
                    VStack {
                        HStack {
                            #if !os(watchOS)
                            if let currentLoc = settings.currentLocation {
                                let currentCity = currentLoc.city
                                
                                Image(systemName: "location.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(settings.accentColor.color)
                                    .padding(.trailing, 8)
                                
                                Text(currentCity)
                                    .font(.subheadline)
                                    .lineLimit(nil)
                            } else {
                                Image(systemName: "location.slash")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(settings.accentColor.color)
                                    .padding(.trailing, 8)
                                
                                Text("No location")
                                    .font(.subheadline)
                                    .lineLimit(nil)
                            }
                            #else
                            if settings.prayers != nil, let currentLoc = settings.currentLocation {
                                let currentCity = currentLoc.city
                                Text(currentCity)
                                    .font(.subheadline)
                                    .lineLimit(nil)
                            } else {
                                Text("No location")
                                    .font(.subheadline)
                                    .lineLimit(nil)
                            }
                            #endif
                            
                            Spacer()
                            
                            QiblaView()
                                .padding(.horizontal)
                        }
                        .foregroundColor(.primary)
                        .font(.subheadline)
                        
                        #if os(watchOS)
                        Text("Compass may not be accurate on Apple Watch")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        #endif
                    }
                }
                
                #if !os(watchOS)
                if settings.prayers != nil && settings.currentLocation != nil {
                    PrayerCountdown()
                        .transition(.opacity)
                    PrayerList()
                        .transition(.opacity)
                }
                #else
                if settings.prayers != nil {
                    PrayerCountdown()
                        .transition(.opacity)
                    PrayerList()
                        .transition(.opacity)
                }
                #endif
            }
            .refreshable {
                prayerTimeRefresh(force: true)
            }
            .onAppear {
                prayerTimeRefresh(force: false)
            }
            .onChange(of: scenePhase) { newScenePhase in
                prayerTimeRefresh(force: false)
            }
            .navigationTitle("Al-Adhan")
            #if !os(watchOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: {
                            showingArabicSheet = true
                        }) {
                            Image(systemName: "textformat.size.ar")
                            Text("Arabic Alphabet")
                        }
                        
                        Button(action: {
                            showingAdhkarSheet = true
                        }) {
                            Image(systemName: "book.closed")
                            Text("Common Adhkar")
                        }
                        
                        Button(action: {
                            showingDuaSheet = true
                        }) {
                            Image(systemName: "text.book.closed")
                            Text("Common Duas")
                        }
                        
                        Button(action: {
                            showingTasbihSheet = true
                        }) {
                            Image(systemName: "circles.hexagonpath.fill")
                            Text("Tasbih Counter")
                        }
                        
                        Button(action: {
                            showingNamesSheet = true
                        }) {
                            Image(systemName: "signature")
                            Text("99 Names of Allah")
                        }
                        
                        Button(action: {
                            showingDateSheet = true
                        }) {
                            Image(systemName: "calendar")
                            Text("Hijri Calendar Converter")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .padding(.leading, settings.defaultView ? 6 : 0)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        settings.hapticFeedback()
                        
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .padding(.trailing, settings.defaultView ? 6 : 0)
                }
            }
            .sheet(isPresented: $showingArabicSheet) {
                NavigationView {
                    ArabicView()
                        .accentColor(settings.accentColor.color)
                }
            }
            .sheet(isPresented: $showingAdhkarSheet) {
                NavigationView {
                    AdhkarView()
                        .accentColor(settings.accentColor.color)
                }
            }
            .sheet(isPresented: $showingDuaSheet) {
                NavigationView {
                    DuaView()
                        .accentColor(settings.accentColor.color)
                }
            }
            .sheet(isPresented: $showingTasbihSheet) {
                NavigationView {
                    TasbihView()
                        .accentColor(settings.accentColor.color)
                }
            }
            .sheet(isPresented: $showingNamesSheet) {
                NavigationView {
                    NamesView()
                        .accentColor(settings.accentColor.color)
                        .environmentObject(namesData)
                }
            }
            .sheet(isPresented: $showingDateSheet) {
                NavigationView {
                    DateView()
                        .accentColor(settings.accentColor.color)
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
                    .accentColor(settings.accentColor.color)
                    .preferredColorScheme(settings.colorScheme)
                    .navigationBarTitleDisplayMode(.inline)
            }
            #endif
            .applyConditionalListStyle(defaultView: settings.defaultView)
        }
        .onChange(of: settings.selectedDate) { value in
            settings.datePrayers = settings.getPrayerTimes(for: value) ?? []
            settings.dateFullPrayers = settings.getPrayerTimes(for: value, fullPrayers: true) ?? []
            
            let calendar = Calendar.current
            
            if !calendar.isDate(value, inSameDayAs: Date()) {
                settings.changedDate = true
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

            case .locationAlert:
                Button("Open Settings") {
                    #if !os(watchOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    #endif
                }
                Button("Never Ask Again", role: .destructive) {
                    settings.locationNeverAskAgain = true
                }
                Button("Ignore", role: .cancel) { }

            case .notificationAlert:
                Button("Open Settings") {
                    #if !os(watchOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    #endif
                }
                Button("Never Ask Again", role: .destructive) {
                    settings.notificationNeverAskAgain = true
                }
                Button("Ignore", role: .cancel) { }

            case .none:
                EmptyView()
            }
        } message: {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Text("Al-Adhan has automatically detected that you are traveling, so your prayers will be shortened.")
            case .travelTurnOffAutomatic:
                Text("Al-Adhan has automatically detected that you are no longer traveling, so your prayers will not be shortened.")
            case .locationAlert:
                Text("Please go to Settings and enable location services to accurately determine prayer times.")
            case .notificationAlert:
                Text("Please go to Settings and enable notifications to be notified of prayer times.")
            case .none:
                EmptyView()
            }
        }
        .navigationViewStyle(.stack)
    }
}
