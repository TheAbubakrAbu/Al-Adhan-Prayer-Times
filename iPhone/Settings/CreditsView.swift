#if os(iOS)
import SwiftUI

struct CreditsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            creditsList
                .adaptiveSafeArea(edge: .bottom) {
                    doneButton
                }
        }
    }

    private var creditsList: some View {
        List {
            headerSection
            storySection
            versionSection
            creditsLinksSection
            appsSection
            botsSection
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(settings.accentColor.color)
        .tint(settings.accentColor.color)
        .navigationTitle("Credits")
    }

    private var headerSection: some View {
        VStack(alignment: .center) {
            Text("Al-Adhan was created by Abubakr Elmallah (أبوبكر الملاح), who was a 17-year-old high school student when this app was published on December 31, 2023.")
                .font(.headline)
                .padding(.vertical, 4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            if let url = URL(string: "https://abubakrelmallah.com/") {
                Link("abubakrelmallah.com", destination: url)
                    .foregroundColor(settings.accentColor.color)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)
                    .padding(.bottom, 8)
                    .contextMenu {
                        Button {
                            settings.hapticFeedback()
                            UIPasteboard.general.string = "https://abubakrelmallah.com/"
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Website")
                            }
                        }
                    }
            }

            Divider()
                .background(settings.accentColor.color)
                .padding(.trailing, -100)
        }
        .listRowSeparator(.hidden)
    }

    private var storySection: some View {
        Section {
            Text("""
            This app was inspired by my desire to help new reverts and non-Muslims learn about Islam and easily access the Quran and prayer times. I’m deeply grateful to my parents for instilling in me a love for the faith (may Allah reward them).

            I also want to express my gratitude to my high school teacher, Mr. Joe Silvey, who, despite not being Muslim, stood with our Muslim Student Association and helped us organize weekly Jumuah prayers.
            """)
                .font(.body)
                .multilineTextAlignment(.leading)

            if let url = URL(string: "https://github.com/TheAbubakrAbu/Al-Adhan-Prayer-Times") {
                Link(
                    "View the source code: github.com/TheAbubakrAbu/Al-Adhan-Prayer-Times",
                    destination: url
                )
                .font(.body)
                .foregroundColor(settings.accentColor.color)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = "https://github.com/TheAbubakrAbu/Al-Adhan-Prayer-Times"
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Website")
                        }
                    }
                }
            }
        }
    }

    private var versionSection: some View {
        Section {
            VersionNumber()
                .font(.caption)
        }
    }

    private var creditsLinksSection: some View {
        Section(header: Text("CREDITS")) {
            Group {
                creditLink("Credit for the Adhan calculations, which does everything offline on the device, goes to Batoul Apps", url: "https://github.com/batoulapps/adhan-swift")
                
                creditLink("Credit for the Adhan sounds goes to Omar Al-Ejel", url: "https://github.com/oalejel/Athan-Utility")
                
                creditLink("Credit for the Uthmani Quran font goes to quran-data-kfgqpc (KFGQPC)", url: "https://github.com/thetruetruth/quran-data-kfgqpc/tree/main/qumbul/font")
                                
                creditLink("Credit for the 99 Names of Allah goes to MyIslam", url: "https://myislam.org/99-names-of-allah/")
            }
            .foregroundColor(settings.accentColor.color)
            .font(.body)
        }
    }

    private var appsSection: some View {
        Section(header: Text("APPS BY ABUBAKR ELMALLAH")) {
            ForEach(appsByAbubakr) { app in
                AppLinkRow(imageName: app.imageName, title: app.title, url: app.url)
            }
        }
    }

    private var botsSection: some View {
        Section(header: Text("DISCORD BOTS BY ABUBAKR ELMALLAH")) {
            ForEach(botsByAbubakr) { bot in
                AppLinkRow(imageName: bot.imageName, title: bot.title, url: bot.url)
            }
        }
    }

    @ViewBuilder
    private func creditLink(_ title: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(title, destination: destination)
                .contextMenu {
                    Button {
                        settings.hapticFeedback()
                        UIPasteboard.general.string = title
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                }
        }
    }

    private var doneButton: some View {
        Button {
            settings.hapticFeedback()
            presentationMode.wrappedValue.dismiss()
        } label: {
            Text("Done")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .foregroundColor(settings.accentColor.color)
        .conditionalGlassEffect(useColor: 0.25)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

let appsByAbubakr: [AppItem] = [
    AppItem(imageName: "Al-Adhan", title: "Al-Adhan | Prayer Times", url: "https://apps.apple.com/us/app/al-adhan-prayer-times/id6475015493?platform=iphone"),
    AppItem(imageName: "Al-Islam", title: "Al-Islam | Islamic Pillars", url: "https://apps.apple.com/us/app/al-islam-islamic-pillars/id6449729655?platform=iphone"),
    AppItem(imageName: "Al-Quran", title: "Al-Quran | Beginner Quran", url: "https://apps.apple.com/us/app/al-quran-beginner-quran/id6474894373?platform=iphone"),
    AppItem(imageName: "ICOI", title: "Islamic Center of Irvine (ICOI)", url: "https://apps.apple.com/us/app/islamic-center-of-irvine/id6463835936?platform=iphone"),
    AppItem(imageName: "Aurebesh", title: "Aurebesh Translator", url: "https://apps.apple.com/us/app/aurebesh-translator/id6670201513?platform=iphone"),
    AppItem(imageName: "Datapad", title: "Datapad | Aurebesh Translator", url: "https://apps.apple.com/us/app/datapad-aurebesh-translator/id6450498054?platform=iphone"),
]

let botsByAbubakr: [AppItem] = [
    AppItem(imageName: "SabaccDroid", title: "Sabacc Droid", url: "https://discordbotlist.com/bots/sabaac-droid"),
    AppItem(imageName: "AurebeshDroid", title: "Aurebesh Droid", url: "https://discordbotlist.com/bots/aurebesh-droid")
]

struct AppItem: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let url: String
}

struct AppLinkRow: View {
    @EnvironmentObject var settings: Settings
    
    var imageName: String
    var title: String
    var url: String

    var body: some View {
        HStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(12)
                .frame(width: 50, height: 50)
                .padding(.trailing, 8)

            if let destination = URL(string: url) {
                Link(title, destination: destination)
                    .font(.subheadline)
            }
        }
        .contextMenu {
            Button {
                settings.hapticFeedback()
                UIPasteboard.general.string = url
            } label: {
                Label("Copy Website", systemImage: "doc.on.doc")
            }
        }
    }
}

#Preview {
    AlIslamPreviewContainer(embedInNavigation: false) {
        CreditsView()
    }
}
#endif
