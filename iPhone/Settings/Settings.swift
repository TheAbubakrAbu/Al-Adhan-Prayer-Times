import SwiftUI
import Adhan
import CoreLocation
import UserNotifications
import WidgetKit

struct Location: Codable, Equatable {
    var city: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

struct Prayer: Identifiable, Codable, Equatable {
    var id = UUID()
    let nameArabic: String
    let nameTransliteration: String
    let nameEnglish: String
    let time: Date
    let image: String
    let rakah: String
    let sunnahBefore: String
    let sunnahAfter: String
    
    static func ==(lhs: Prayer, rhs: Prayer) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Prayers: Identifiable, Codable, Equatable {
    var id = UUID()
    let day: Date
    let city: String
    let prayers: [Prayer]
    let fullPrayers: [Prayer]
    var setNotification: Bool
}

extension Date {
    func isSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
    
    func addingMinutes(_ minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}

struct LetterData: Identifiable, Codable, Equatable, Comparable {
    let id: Int
    let letter: String
    let forms: [String]
    let name: String
    let transliteration: String
    let showTashkeel: Bool
    let sound: String
    
    static func < (lhs: LetterData, rhs: LetterData) -> Bool {
        return lhs.id < rhs.id
    }
}

enum AccentColor: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }

    case red, orange, yellow, green, blue, indigo, cyan, teal, mint, purple, pink, brown

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .indigo: return .indigo
        case .cyan: return .cyan
        case .teal: return .teal
        case .mint: return .mint
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        }
    }
}

let accentColors: [AccentColor] = AccentColor.allCases

extension CLLocationCoordinate2D {
    var stringRepresentation: String {
        let lat = String(format: "%.3f", self.latitude)
        let lon = String(format: "%.3f", self.longitude)
        return "(\(lat), \(lon))"
    }
}

extension Double {
    var stringRepresentation: String {
        return String(format: "%.3f", self)
    }
}

struct HijriDate: Identifiable, Codable {
    var id: Date { date }
    
    let english: String
    let arabic: String
    let date: Date
}

class Settings: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = Settings()
    private var appGroupUserDefaults: UserDefaults?
    
    @AppStorage("hijriDate") private var hijriDateData: String?
    var hijriDate: HijriDate? {
        get {
            guard let hijriDateData = hijriDateData,
                  let data = hijriDateData.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(HijriDate.self, from: data)
        }
        set {
            if let newValue = newValue {
                let encoded = try? JSONEncoder().encode(newValue)
                hijriDateData = encoded.flatMap { String(data: $0, encoding: .utf8) }
            } else {
                hijriDateData = nil
            }
        }
    }
    
    private var locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    
    @Published var qiblaDirection: Double = 0
    private let kaabaCoordinates = Coordinates(latitude: 21.4225, longitude: 39.8262)
    
    override init() {
        self.appGroupUserDefaults = UserDefaults(suiteName: "group.com.IslamicPillars.AppGroup")
        
        self.accentColor = AccentColor(rawValue: appGroupUserDefaults?.string(forKey: "colorAccent2") ?? "yellow") ?? .yellow
        
        self.prayersData = appGroupUserDefaults?.data(forKey: "prayersData") ?? Data()
        
        self.travelingMode = appGroupUserDefaults?.bool(forKey: "travelingMode") ?? false
        
        self.hanafiMadhab = appGroupUserDefaults?.bool(forKey: "hanafiMadhab") ?? false
        
        self.prayerCalculation = appGroupUserDefaults?.string(forKey: "prayerCalculation") ?? "Muslim World League"
        
        self.hijriOffset = appGroupUserDefaults?.integer(forKey: "hijriOffset") ?? 0
        
        if let locationData = appGroupUserDefaults?.data(forKey: "currentLocation") {
            do {
                let location = try JSONDecoder().decode(Location.self, from: locationData)
                currentLocation = location
            } catch {
                print("Failed to decode location: \(error)")
            }
        }
        
        if let homeLocationData = appGroupUserDefaults?.data(forKey: "homeLocationData") {
            do {
                let homeLocation = try JSONDecoder().decode(Location.self, from: homeLocationData)
                self.homeLocation = homeLocation
            } catch {
                print("Failed to decode home location: \(error)")
            }
        }
        
        self.favoriteLetterData = appGroupUserDefaults?.data(forKey: "favoriteLetterData") ?? Data()
        
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        #if !os(watchOS)
        requestLocationAuthorization()
        #else
        requestLocationAuthorization()
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("Location Manager Before: \(location.coordinate.latitude), \(location.coordinate.longitude) at \(location.timestamp)")
        
        if let currentLocation = self.currentLocation {
            let previousLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            let newLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            let distanceInMeters = previousLocation.distance(from: newLocation)
            let distanceInMiles = distanceInMeters / 1609.34
            
            if distanceInMiles < 1 {
                return
            }
        }
        
        print("Location Manager After: \(location.coordinate.latitude), \(location.coordinate.longitude) at \(location.timestamp)")
        
        updateCity(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) {
            self.fetchPrayerTimes()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let currentLocation = self.currentLocation else { return }
        
        let coordinates = Coordinates(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let qibla = Qibla(coordinates: coordinates)
        let angle = qibla.direction - newHeading.trueHeading
        
        self.qiblaDirection = angle
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied:
            print("Location authorization denied.")
            if !locationNeverAskAgain {
                withAnimation {
                    showLocationAlert = true
                }
            }
        case .authorizedAlways, .authorizedWhenInUse:
            withAnimation {
                showLocationAlert = false
            }
        case .restricted, .notDetermined:
            print("Location authorization is restricted or not determined.")
        @unknown default:
            break
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error.localizedDescription)")
    }
    
    func requestLocationAuthorization() {
        locationManager.requestAlwaysAuthorization()
        
        locationManager.startUpdatingHeading()
        #if !os(watchOS)
        locationManager.startMonitoringSignificantLocationChanges()
        #else
        locationManager.startUpdatingLocation()
        #endif
    }
    
    func updateCity(latitude: Double, longitude: Double, completion: (() -> Void)? = nil) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        print("Updating city...")

        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self.updateCurrentLocation(from: placemark, latitude: latitude, longitude: longitude)
                } else if let error = error {
                    print("Geocoding Error: \(error.localizedDescription)")
                    self.retryUpdateCity(latitude: latitude, longitude: longitude, completion: completion)
                }
                WidgetCenter.shared.reloadAllTimelines()
                completion?()
            }
        }
    }

    func updateCurrentLocation(from placemark: CLPlacemark, latitude: Double, longitude: Double) {
        if let city = placemark.locality {
            let region = placemark.administrativeArea ?? placemark.country ?? ""
            withAnimation {
                self.currentLocation = Location(city: "\(city), \(region)", latitude: latitude, longitude: longitude)
            }
        } else {
            withAnimation {
                self.currentLocation = Location(city: "\(latitude.stringRepresentation), \(longitude.stringRepresentation)", latitude: latitude, longitude: longitude)
            }
        }
    }

    func retryUpdateCity(latitude: Double, longitude: Double, retries: Int = 3, completion: (() -> Void)? = nil) {
        guard retries > 0 else {
            self.currentLocation = Location(city: "\(latitude.stringRepresentation), \(longitude.stringRepresentation)", latitude: latitude, longitude: longitude)
            completion?()
            return
        }

        let delaySeconds = Double(4 - retries)
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
            self.updateCity(latitude: latitude, longitude: longitude, completion: completion)
        }
    }
    
    func checkIfTraveling() {
        guard let currentLocation = self.currentLocation, let homeLocation = self.homeLocation else { return }

        if currentLocation.latitude != 1000 && currentLocation.longitude != 1000 {
            let location = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            let homeCLLocation = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
            let distanceInMeters = location.distance(from: homeCLLocation) // this is in meters
            let distanceInMiles = distanceInMeters / 1609.34 // convert to miles
            
            if distanceInMiles >= 48 {
                if !travelingMode {
                    print("Traveling: on")
                    withAnimation {
                        travelingMode = true
                    }
                    DispatchQueue.main.async {
                        self.travelTurnOffAutomatic = false
                        self.travelTurnOnAutomatic = true
                        
                        #if !os(watchOS)
                        let content = UNMutableNotificationContent()
                        content.title = "Al-Adhan | Prayer Times"
                        content.body = "Traveling mode automatically turned on at \(currentLocation.city)"
                        content.sound = UNNotificationSound.default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request)
                        #endif
                    }
                }
            } else {
                if travelingMode {
                    print("Traveling off")
                    withAnimation {
                        travelingMode = false
                    }
                    DispatchQueue.main.async {
                        self.travelTurnOnAutomatic = false
                        self.travelTurnOffAutomatic = true
                        
                        #if !os(watchOS)
                        let content = UNMutableNotificationContent()
                        content.title = "Al-Adhan | Prayer Times"
                        content.body = "Traveling mode automatically turned off at \(currentLocation.city)"
                        content.sound = UNNotificationSound.default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request)
                        #endif
                    }
                }
            }
        }
    }
    
    func arabicNumberString(from numberString: String) -> String {
        let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

        var arabicNumberString = ""
        for character in numberString {
            if let digit = Int(String(character)) {
                arabicNumberString += arabicNumbers[digit]
            } else {
                arabicNumberString += String(character)
            }
        }
        return arabicNumberString
    }
    
    func formatArabicDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "ar")
        let dateInEnglish = formatter.string(from: date)
        return arabicNumberString(from: dateInEnglish)
    }
    
    private let hijriDateFormatterArabic: DateFormatter = {
        let formatter = DateFormatter()
        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.locale = Locale(identifier: "ar")
        formatter.calendar = hijriCalendar
        formatter.dateFormat = "d MMMM، yyyy"
        formatter.locale = Locale(identifier: "ar")
        return formatter
    }()

    private let hijriDateFormatterEnglish: DateFormatter = {
        let formatter = DateFormatter()
        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.locale = Locale(identifier: "ar")
        formatter.calendar = hijriCalendar
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "en")
        return formatter
    }()
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    func updateDates() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let currentDateString = dateFormatter.string(from: Date())
        let currentDateInRiyadh = dateFormatter.date(from: currentDateString) ?? Date()

        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.locale = Locale(identifier: "ar")
        
        let offsetDate = hijriCalendar.date(byAdding: .day, value: hijriOffset, to: currentDateInRiyadh) ?? currentDateInRiyadh

        let hijriComponents = hijriCalendar.dateComponents([.year, .month, .day], from: offsetDate)
        let hijriDateArabicValue = hijriCalendar.date(from: hijriComponents)

        withAnimation {
            let currentDate = Date()
            let arabicFormattedDate = hijriDateFormatterArabic.string(from: hijriDateArabicValue ?? offsetDate)
            let hijriArabic = arabicNumberString(from: arabicFormattedDate) + " هـ"
            let hijriEnglish = hijriDateFormatterEnglish.string(from: hijriDateArabicValue ?? offsetDate)
            
            self.hijriDate = HijriDate(english: hijriEnglish, arabic: hijriArabic, date: currentDate)
        }
    }
    
    func updateCurrentAndNextPrayer() {
        if let prayersObject = prayers {
            let prayersToday = prayersObject.prayers
            
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let prayersTomorrow = getPrayerTimes(for: tomorrow) ?? []
            
            let now = Date()
            
            let current = prayersToday.last(where: { $0.time <= now })
            let next = prayersToday.first(where: { $0.time > now })
            
            if let next = next {
                nextPrayer = next
            } else if let firstTomorrowPrayer = prayersTomorrow.first, now < firstTomorrowPrayer.time {
                nextPrayer = firstTomorrowPrayer
            }
            
            currentPrayer = current ?? prayersToday.last
        } else {
            print("Failed to get today's prayer times")
        }
    }
    
    func getPrayerTimes(for date: Date, fullPrayers: Bool = false) -> [Prayer]? {
        guard let currentLoc = currentLocation,
              currentLoc.latitude != 1000,
              currentLoc.longitude != 1000 else {
            return nil
        }

        let coordinates = Coordinates(latitude: currentLoc.latitude, longitude: currentLoc.longitude)
        let cal = Calendar(identifier: .gregorian)
        let dateComponents = cal.dateComponents([.year, .month, .day], from: date)
        let weekday = Calendar.current.component(.weekday, from: date)
        let isFriday = (weekday == 6)

        var params = CalculationMethod.muslimWorldLeague.params
        if prayerCalculation == "Muslim World League" { params = CalculationMethod.muslimWorldLeague.params }
        else if prayerCalculation == "Moonsight Committee" { params = CalculationMethod.moonsightingCommittee.params }
        else if prayerCalculation == "Umm Al-Qura" { params = CalculationMethod.ummAlQura.params }
        else if prayerCalculation == "Egypt" { params = CalculationMethod.egyptian.params }
        else if prayerCalculation == "Dubai" { params = CalculationMethod.dubai.params }
        else if prayerCalculation == "Kuwait" { params = CalculationMethod.kuwait.params }
        else if prayerCalculation == "Qatar" { params = CalculationMethod.qatar.params }
        else if prayerCalculation == "Turkey" { params = CalculationMethod.turkey.params }
        else if prayerCalculation == "Tehran" { params = CalculationMethod.tehran.params }
        else if prayerCalculation == "Karachi" { params = CalculationMethod.karachi.params }
        else if prayerCalculation == "Singapore" { params = CalculationMethod.singapore.params }
        else if prayerCalculation == "North America" { params = CalculationMethod.northAmerica.params }

        params.madhab = hanafiMadhab ? .hanafi : .shafi

        guard let rawPrayers = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            return nil
        }

        let offsetFajrTime = rawPrayers.fajr.addingMinutes(offsetFajr)
        let offsetSunriseTime = rawPrayers.sunrise.addingMinutes(offsetSunrise)
        let offsetDhuhrTime = rawPrayers.dhuhr.addingMinutes(offsetDhuhr)
        let offsetAsrTime = rawPrayers.asr.addingMinutes(offsetAsr)
        let offsetMaghribTime = rawPrayers.maghrib.addingMinutes(offsetMaghrib)
        let offsetIshaTime = rawPrayers.isha.addingMinutes(offsetIsha)
        let offsetDhuhrAsrTime = rawPrayers.dhuhr.addingMinutes(offsetDhurhAsr)
        let offsetMaghribIshaTime = rawPrayers.maghrib.addingMinutes(offsetMaghribIsha)

        if fullPrayers || !travelingMode {
            return [
                Prayer(nameArabic: "الفَجْر", nameTransliteration: "Fajr", nameEnglish: "Dawn", time: offsetFajrTime, image: "sunrise", rakah: "2", sunnahBefore: "2", sunnahAfter: "0"),
                Prayer(nameArabic: "الشُرُوق", nameTransliteration: "Shurooq", nameEnglish: "Sunrise", time: offsetSunriseTime, image: "sunrise.fill", rakah: "0", sunnahBefore: "0", sunnahAfter: "0"),
                Prayer(nameArabic: isFriday ? "الجُمُعَة" : "الظُهْر", nameTransliteration: isFriday ? "Jummuah" : "Dhuhr", nameEnglish: isFriday ? "Friday" : "Noon", time: offsetDhuhrTime, image: "sun.max\(isFriday ? ".fill" : "")", rakah: isFriday ? "2" : "4", sunnahBefore: isFriday ? "0" : "2 and 2", sunnahAfter: isFriday ? "2 and 2" : "2"),
                Prayer(nameArabic: "العَصْر", nameTransliteration: "Asr", nameEnglish: "Afternoon", time: offsetAsrTime, image: "sun.min", rakah: "4", sunnahBefore: "0", sunnahAfter: "0"),
                Prayer(nameArabic: "المَغْرِب", nameTransliteration: "Maghrib", nameEnglish: "Sunset", time: offsetMaghribTime, image: "sunset", rakah: "3", sunnahBefore: "0", sunnahAfter: "2"),
                Prayer(nameArabic: "العِشَاء", nameTransliteration: "Isha", nameEnglish: "Night", time: offsetIshaTime, image: "moon", rakah: "4", sunnahBefore: "0", sunnahAfter: "2")
            ]
        } else {
            return [
                Prayer(nameArabic: "الفَجْر", nameTransliteration: "Fajr", nameEnglish: "Dawn", time: offsetFajrTime, image: "sunrise", rakah: "2", sunnahBefore: "2", sunnahAfter: "0"),
                Prayer(nameArabic: "الشُرُوق", nameTransliteration: "Shurooq", nameEnglish: "Sunrise", time: offsetSunriseTime, image: "sunrise.fill", rakah: "0", sunnahBefore: "0", sunnahAfter: "0"),
                Prayer(nameArabic: "الظُهْر وَالْعَصْر", nameTransliteration: "Dhuhr/Asr", nameEnglish: "Daytime", time: offsetDhuhrAsrTime, image: "sun.max", rakah: "2 and 2", sunnahBefore: "0", sunnahAfter: "0"),
                Prayer(nameArabic: "المَغْرِب وَالْعِشَاء", nameTransliteration: "Maghrib/Isha", nameEnglish: "Nighttime", time: offsetMaghribIshaTime, image: "sunset", rakah: "3 and 2", sunnahBefore: "0", sunnahAfter: "0")
            ]
        }
    }
    
    func fetchPrayerTimes(force: Bool = false, notification: Bool = false, isRecursiveCall: Bool = false, calledFrom: String = #function) {
        var hasUpdatedNotifications = false
        
        let currentDate = Date()
        
        if hijriDate == nil { updateDates() }
        
        if let hijriDate = self.hijriDate, !(hijriDate.date.isSameDay(as: currentDate)) {
            updateDates()
        }
        
        guard let currentLoc = self.currentLocation,
              currentLoc.latitude != 1000,
              currentLoc.longitude != 1000 else {
            print("No location set")
            return
        }
        
        if currentLoc.city.contains("(") && !isRecursiveCall {
            updateCity(latitude: currentLoc.latitude, longitude: currentLoc.longitude) {
                self.fetchPrayerTimes(force: force, notification: notification, isRecursiveCall: true, calledFrom: calledFrom)
                return
            }
        }
        
        if travelAutomatic && homeLocation != nil { checkIfTraveling() }
                
        let prayersObject = self.prayers
        if force || prayersObject == nil || (prayersObject?.prayers.isEmpty ?? true) || !(prayersObject?.day.isSameDay(as: currentDate) ?? false) || (prayersObject?.city != currentLoc.city) {
            print("Fetching normal prayer times. Called from \(calledFrom)")
                        
            let prayers = getPrayerTimes(for: currentDate) ?? []
            let fullPrayers = getPrayerTimes(for: currentDate, fullPrayers: true) ?? []
            
            self.prayers = Prayers(day: currentDate, city: currentLoc.city, prayers: prayers, fullPrayers: fullPrayers, setNotification: false)
            
            schedulePrayerTimeNotifications()
            hasUpdatedNotifications = true
            
            printAllScheduledNotifications()
            
            WidgetCenter.shared.reloadAllTimelines()
        }
            
        if let prayersObject = prayers, !prayersObject.setNotification || (notification && !hasUpdatedNotifications) {
            schedulePrayerTimeNotifications()
            
            printAllScheduledNotifications()
        }
            
        updateCurrentAndNextPrayer()
    }
    
    func requestNotificationAuthorization(completion: (() -> Void)? = nil) {
        #if !os(watchOS)
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
                    DispatchQueue.main.async {
                        if granted {
                            if self.showNotificationAlert {
                                self.fetchPrayerTimes(notification: true)
                            }
                            self.showNotificationAlert = false
                        } else {
                            if !self.notificationNeverAskAgain {
                                self.showNotificationAlert = true
                            }
                        }
                        completion?()
                    }
                }
            case .authorized:
                DispatchQueue.main.async {
                    if self.showNotificationAlert {
                        self.fetchPrayerTimes(notification: true)
                    }
                    self.showNotificationAlert = false
                    completion?()
                }
            case .denied:
                DispatchQueue.main.async {
                    self.showNotificationAlert = true
                    print("Permission denied")
                    if !self.notificationNeverAskAgain {
                        self.showNotificationAlert = true
                    }
                    completion?()
                }
            default:
                completion?()
                break
            }
        }
        #else
        completion?()
        #endif
    }
    
    func printAllScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { (requests) in
            for request in requests {
                print(request.content.body)
            }
        }
    }
    
    func schedulePrayerTimeNotifications() {
        #if !os(watchOS)
        guard let currentLoc = currentLocation, let prayerObject = prayers else { return }
        
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let prayerTimes = prayerObject.prayers
        print("Scheduling prayer times")
        
        for prayerTime in prayerTimes {
            var preNotificationTime: Int?
            var shouldScheduleNotification: Bool
            var naggingPrayerEnabled = false

            switch prayerTime.nameTransliteration {
            case "Fajr":
                preNotificationTime = preNotificationFajr
                shouldScheduleNotification = notificationFajr
                naggingPrayerEnabled = naggingFajr
            case "Shurooq":
                preNotificationTime = preNotificationSunrise
                shouldScheduleNotification = notificationSunrise
                naggingPrayerEnabled = naggingSunrise
            case "Dhuhr", "Dhuhr/Asr", "Jummuah":
                preNotificationTime = preNotificationDhuhr
                shouldScheduleNotification = notificationDhuhr
                naggingPrayerEnabled = naggingDhuhr
            case "Asr":
                preNotificationTime = preNotificationAsr
                shouldScheduleNotification = notificationAsr
                naggingPrayerEnabled = naggingAsr
            case "Maghrib", "Maghrib/Isha":
                preNotificationTime = preNotificationMaghrib
                shouldScheduleNotification = notificationMaghrib
                naggingPrayerEnabled = naggingMaghrib
            case "Isha":
                preNotificationTime = preNotificationIsha
                shouldScheduleNotification = notificationIsha
                naggingPrayerEnabled = naggingIsha
            default:
                continue
            }
            
            if naggingMode && naggingPrayerEnabled {
                scheduleNotification(for: prayerTime, preNotificationTime: nil, city: currentLoc.city)
                
                let offsets = naggingOffsets(from: naggingStartOffset)
                for offset in offsets {
                    scheduleNotification(for: prayerTime, preNotificationTime: offset, city: currentLoc.city)
                }
            } else {
                if shouldScheduleNotification {
                    scheduleNotification(for: prayerTime, preNotificationTime: nil, city: currentLoc.city)
                }
                
                if let preNotificationTime = preNotificationTime, preNotificationTime > 0 {
                    scheduleNotification(for: prayerTime, preNotificationTime: preNotificationTime, city: currentLoc.city)
                }
            }
        }
        
        prayers?.setNotification = true
        #endif
    }
    
    private func naggingOffsets(from startOffset: Int) -> [Int] {
        var results = [Int]()
        var current = startOffset
        
        while current > 15 {
            results.append(current)
            current -= 15
        }
        
        if current == 15 {
            results.append(15)
        } else if current < 15 && current > 5 {
            results.append(current)
        }
        
        results.append(10)
        results.append(5)
        
        return results
    }

    func scheduleNotification(for prayerTime: Prayer, preNotificationTime: Int?, city: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Al-Adhan | Prayer Times"
        
        let triggerTime: Date
        if let preNotificationTime = preNotificationTime, preNotificationTime != 0 {
            triggerTime = Calendar.current.date(byAdding: .minute, value: -preNotificationTime, to: prayerTime.time)!
            
            if prayerTime.nameTransliteration == "Shurooq" {
                content.body = "\(prayerTime.nameTransliteration) (\(prayerTime.nameEnglish.lowercased())) in \(preNotificationTime) minutes in \(city)" + (travelingMode ? " (traveling mode)" : "") + " [\(self.formatDate(prayerTime.time))]"
            } else {
                let prayerName = prayerTime.nameEnglish.lowercased() == "friday" ? "Friday" : prayerTime.nameEnglish.lowercased()
                let contentBody = "\(prayerTime.nameTransliteration) (\(prayerName)) in \(preNotificationTime) minutes in \(city)" + (travelingMode ? " (traveling mode)" : "") + " [\(self.formatDate(prayerTime.time))]"
                content.body = contentBody
            }
        } else {
            triggerTime = prayerTime.time
            
            if prayerTime.nameTransliteration == "Shurooq" {
                content.body = "Time for shurooq (sunrise - ending of Fajr) at \(self.formatDate(prayerTime.time)) in \(city)" + (travelingMode ? " (traveling mode)" : "")
            } else if prayerTime.nameTransliteration == "Fajr" {
                content.body = {
                    guard let prayers = self.prayers, prayers.prayers.count > 1 else {
                        return "Error: Not enough prayer times available"
                    }
                    return "Time to pray \(prayerTime.nameTransliteration) (\(prayerTime.nameEnglish.lowercased())) at \(self.formatDate(prayerTime.time)) in \(city)" + (travelingMode ? " (traveling mode)" : "") + " [ends at \(self.formatDate(prayers.prayers[1].time))]"
                }()
            } else {
                let prayerName = prayerTime.nameEnglish.lowercased() == "friday" ? "Friday" : prayerTime.nameEnglish.lowercased()
                let contentBody = "Time to pray \(prayerTime.nameTransliteration) (\(prayerName)) at \(self.formatDate(prayerTime.time)) in \(city)" + (travelingMode ? " (traveling mode)" : "")
                content.body = contentBody

            }
        }
        
        guard triggerTime > Date() else {
            return
        }
        
        content.sound = UNNotificationSound.default
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: triggerTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func hapticFeedback() {
        #if os(iOS)
        if hapticOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
        
        #if os(watchOS)
        if hapticOn { WKInterfaceDevice.current().play(.click) }
        #endif
    }
    
    @Published var prayersData: Data {
        didSet {
            if !prayersData.isEmpty {
                appGroupUserDefaults?.setValue(prayersData, forKey: "prayersData")
            }
        }
    }
    var prayers: Prayers? {
        get {
            let decoder = JSONDecoder()
            return try? decoder.decode(Prayers.self, from: prayersData)
        }
        set {
            let encoder = JSONEncoder()
            prayersData = (try? encoder.encode(newValue)) ?? Data()
        }
    }
    
    @AppStorage("currentPrayerData") var currentPrayerData: Data?
    @Published var currentPrayer: Prayer? {
        didSet {
            let encoder = JSONEncoder()
            currentPrayerData = try? encoder.encode(currentPrayer)
        }
    }

    @AppStorage("nextPrayerData") var nextPrayerData: Data?
    @Published var nextPrayer: Prayer? {
        didSet {
            let encoder = JSONEncoder()
            nextPrayerData = try? encoder.encode(nextPrayer)
        }
    }
    
    @Published var accentColor: AccentColor {
        didSet { appGroupUserDefaults?.setValue(accentColor.rawValue, forKey: "colorAccent2") }
    }
    
    @Published var travelingMode: Bool {
        didSet { appGroupUserDefaults?.setValue(travelingMode, forKey: "travelingMode") }
    }
    
    @Published var currentLocation: Location? {
        didSet {
            guard let location = currentLocation else { return }
            do {
                let locationData = try JSONEncoder().encode(location)
                appGroupUserDefaults?.setValue(locationData, forKey: "currentLocation")
            } catch {
                print("Failed to encode location: \(error)")
            }
        }
    }
    
    @Published var homeLocation: Location? {
        didSet {
            guard let homeLocation = homeLocation else {
                appGroupUserDefaults?.removeObject(forKey: "homeLocationData")
                return
            }
            do {
                let homeLocationData = try JSONEncoder().encode(homeLocation)
                appGroupUserDefaults?.set(homeLocationData, forKey: "homeLocationData")
            } catch {
                print("Failed to encode home location: \(error)")
            }
        }
    }
    
    @Published var hanafiMadhab: Bool {
        didSet { appGroupUserDefaults?.setValue(hanafiMadhab, forKey: "hanafiMadhab") }
    }
    
    @Published var prayerCalculation: String {
        didSet { appGroupUserDefaults?.setValue(prayerCalculation, forKey: "prayerCalculation") }
    }
    
    @Published var hijriOffset: Int {
        didSet { appGroupUserDefaults?.setValue(hijriOffset, forKey: "hijriOffset") }
    }

    @Published var favoriteLetterData: Data {
        didSet {
            appGroupUserDefaults?.setValue(favoriteLetterData, forKey: "favoriteLetterData")
        }
    }
    var favoriteLetters: [LetterData] {
        get {
            let decoder = JSONDecoder()
            return (try? decoder.decode([LetterData].self, from: favoriteLetterData)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            favoriteLetterData = (try? encoder.encode(newValue)) ?? Data()
        }
    }
    
    func dictionaryRepresentation() -> [String: Any] {
        let encoder = JSONEncoder()
        var dict: [String: Any] = [
            "accentColor": self.accentColor.rawValue,
            
            "travelingMode": self.travelingMode,
            "hanafiMadhab": self.hanafiMadhab,
            "prayerCalculation": self.prayerCalculation,
            "hijriOffset": self.hijriOffset,
            
            "offsetFajr": self.offsetFajr,
            "offsetSunrise": self.offsetSunrise,
            "offsetDhuhr": self.offsetDhuhr,
            "offsetAsr": self.offsetAsr,
            "offsetMaghrib": self.offsetMaghrib,
            "offsetIsha": self.offsetIsha,
            "offsetDhurhAsr": self.offsetDhurhAsr,
            "offsetMaghribIsha": self.offsetMaghribIsha,
        ]
        
        if let currentLocationData = try? encoder.encode(self.currentLocation) {
            dict["currentLocation"] = String(data: currentLocationData, encoding: .utf8)
        } else {
            dict["currentLocation"] = NSNull()
        }
        
        do {
            dict["homeLocationData"] = try encoder.encode(self.homeLocation)
        } catch {
            print("Error encoding homeLocation: \(error)")
        }

        do {
            dict["favoriteLetterData"] = try encoder.encode(self.favoriteLetters)
        } catch {
            print("Error encoding favoriteLetters: \(error)")
        }
        
        return dict
    }

    func update(from dict: [String: Any]) {
        let decoder = JSONDecoder()
        if let accentColor = dict["accentColor"] as? String,
           let accentColorValue = AccentColor(rawValue: accentColor) {
            self.accentColor = accentColorValue
        }
        if let travelingMode = dict["travelingMode"] as? Bool {
            self.travelingMode = travelingMode
        }
        if let hanafiMadhab = dict["hanafiMadhab"] as? Bool {
            self.hanafiMadhab = hanafiMadhab
        }
        if let prayerCalculation = dict["prayerCalculation"] as? String {
            self.prayerCalculation = prayerCalculation
        }
        if let hijriOffset = dict["hijriOffset"] as? Int {
            self.hijriOffset = hijriOffset
        }
        if let currentLocationString = dict["currentLocation"] as? String,
           let currentLocationData = currentLocationString.data(using: .utf8) {
            self.currentLocation = try? decoder.decode(Location.self, from: currentLocationData)
        }
        if let homeLocationData = dict["homeLocationData"] as? Data {
            self.homeLocation = (try? decoder.decode(Location.self, from: homeLocationData)) ?? nil
        }
        if let favoriteLetterData = dict["favoriteLetterData"] as? Data {
            self.favoriteLetters = (try? decoder.decode([LetterData].self, from: favoriteLetterData)) ?? []
        }
    }
    
    @AppStorage("firstLaunch") var firstLaunch = true
    
    @Published var datePrayers: [Prayer]?
    @Published var dateFullPrayers: [Prayer]?
    @Published var selectedDate = Date()
    @Published var changedDate = false
    
    @AppStorage("hapticOn") var hapticOn: Bool = true
    
    @AppStorage("defaultView") var defaultView: Bool = true
    
    @AppStorage("colorSchemeString") var colorSchemeString: String = "system"
    var colorScheme: ColorScheme? {
        get {
            return colorSchemeFromString(colorSchemeString)
        }
        set {
            colorSchemeString = colorSchemeToString(newValue)
        }
    }

    @AppStorage("useSystemFontSize") var useSystemFontSize: Bool = true
    
    @AppStorage("travelAutomatic") var travelAutomatic: Bool = true
    @AppStorage("travelTurnOffAutomatic") var travelTurnOffAutomatic: Bool = false
    @AppStorage("travelTurnOnAutomatic") var travelTurnOnAutomatic: Bool = false
    
    @AppStorage("showLocationAlert") var showLocationAlert: Bool = false
    @AppStorage("showNotificationAlert") var showNotificationAlert: Bool = false
    
    @AppStorage("locationNeverAskAgain") var locationNeverAskAgain = false
    @AppStorage("notificationNeverAskAgain") var notificationNeverAskAgain = false
    
    @AppStorage("naggingMode") var naggingMode: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingStartOffset") var naggingStartOffset: Int = 30 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    
    @AppStorage("preNotificationFajr") var preNotificationFajr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationFajr") var notificationFajr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingFajr") var naggingFajr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetFajr") var offsetFajr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationSunrise") var preNotificationSunrise: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationSunrise") var notificationSunrise: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingSunrise") var naggingSunrise: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetSunrise") var offsetSunrise: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationDhuhr") var preNotificationDhuhr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationDhuhr") var notificationDhuhr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingDhuhr") var naggingDhuhr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetDhuhr") var offsetDhuhr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationAsr") var preNotificationAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationAsr") var notificationAsr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingAsr") var naggingAsr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetAsr") var offsetAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationMaghrib") var preNotificationMaghrib: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationMaghrib") var notificationMaghrib: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingMaghrib") var naggingMaghrib: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetMaghrib") var offsetMaghrib: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationIsha") var preNotificationIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationIsha") var notificationIsha: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingIsha") var naggingIsha: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetIsha") var offsetIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    
    @AppStorage("offsetDhurhAsr") var offsetDhurhAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    @AppStorage("offsetMaghribIsha") var offsetMaghribIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("useFontArabic") var useFontArabic = true
    
    @AppStorage("fontArabic") var fontArabic: String = "KFGQPCUthmanicScriptHAFS"
    
    func currentNotification(prayerTime: Prayer) -> Binding<Bool> {
        switch prayerTime.nameTransliteration {
        case "Fajr": return $notificationFajr
        case "Shurooq": return $notificationSunrise
        case "Dhuhr", "Dhuhr/Asr", "Jummuah": return $notificationDhuhr
        case "Asr": return $notificationAsr
        case "Maghrib", "Maghrib/Isha": return $notificationMaghrib
        case "Isha": return $notificationIsha
        default: return .constant(false)
        }
    }

    func currentPreNotification(prayerTime: Prayer) -> Binding<Int> {
        switch prayerTime.nameTransliteration {
        case "Fajr": return $preNotificationFajr
        case "Shurooq": return $preNotificationSunrise
        case "Dhuhr", "Dhuhr/Asr", "Jummuah": return $preNotificationDhuhr
        case "Asr": return $preNotificationAsr
        case "Maghrib", "Maghrib/Isha": return $preNotificationMaghrib
        case "Isha": return $preNotificationIsha
        default: return .constant(0)
        }
    }
    
    func shouldShowFilledBell(prayerTime: Prayer) -> Bool {
        switch prayerTime.nameTransliteration {
        case "Fajr":
            return notificationFajr && preNotificationFajr > 0
        case "Shurooq":
            return notificationSunrise && preNotificationSunrise > 0
        case "Dhuhr", "Dhuhr/Asr", "Jummuah":
            return notificationDhuhr && preNotificationDhuhr > 0
        case "Asr":
            return notificationAsr && preNotificationAsr > 0
        case "Maghrib", "Maghrib/Isha":
            return notificationMaghrib && preNotificationMaghrib > 0
        case "Isha":
            return notificationIsha && preNotificationIsha > 0
        default:
            return false
        }
    }

    func shouldShowOutlinedBell(prayerTime: Prayer) -> Bool {
        switch prayerTime.nameTransliteration {
        case "Fajr":
            return notificationFajr && preNotificationFajr == 0
        case "Shurooq":
            return notificationSunrise && preNotificationSunrise == 0
        case "Dhuhr", "Dhuhr/Asr", "Jummuah":
            return notificationDhuhr && preNotificationDhuhr == 0
        case "Asr":
            return notificationAsr && preNotificationAsr == 0
        case "Maghrib", "Maghrib/Isha":
            return notificationMaghrib && preNotificationMaghrib == 0
        case "Isha":
            return notificationIsha && preNotificationIsha == 0
        default:
            return false
        }
    }

    func toggleLetterFavorite(letterData: LetterData) {
        withAnimation {
            if isLetterFavorite(letterData: letterData) {
                favoriteLetters.removeAll(where: { $0.id == letterData.id })
            } else {
                favoriteLetters.append(letterData)
            }
        }
    }

    func isLetterFavorite(letterData: LetterData) -> Bool {
        return favoriteLetters.contains(where: {$0.id == letterData.id})
    }
    
    func colorSchemeFromString(_ colorScheme: String) -> ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    func colorSchemeToString(_ colorScheme: ColorScheme?) -> String {
        switch colorScheme {
        case .light:
            return "light"
        case .dark:
            return "dark"
        default:
            return "system"
        }
    }
}

struct CustomColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var customColorScheme: ColorScheme? {
        get { self[CustomColorSchemeKey.self] }
        set { self[CustomColorSchemeKey.self] = newValue }
    }
}

func arabicNumberString(from number: Int) -> String {
    let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
    let numberString = String(number)
    
    var arabicNumberString = ""
    for character in numberString {
        if let digit = Int(String(character)) {
            arabicNumberString += arabicNumbers[digit]
        }
    }
    return arabicNumberString
}
