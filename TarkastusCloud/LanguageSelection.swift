import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, fi, sv, nb, da, et, lv, lt, ru
    var id: String { rawValue }
    var name: String {
        switch self {
        case .en: return "English"
        case .fi: return "Suomi"
        case .sv: return "Svenska"
        case .nb: return "Norsk"
        case .da: return "Dansk"
        case .et: return "Eesti"
        case .lv: return "Latviešu"
        case .lt: return "Lietuvių"
        case .ru: return "Русский"
        }
    }
}
struct LanguageGate<Content: View>: View {
    @AppStorage("appLanguage") private var language = "en"
    @AppStorage("languageSelected") private var selected = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        Group {
            if selected {
                content().environment(\.locale, Locale(identifier: language))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tarkastus Cloud").font(.largeTitle)
                        Text("Choose your language").font(.title2)
                        Text("English is selected by default. You can change the language later in Settings.")
                        ForEach(AppLanguage.allCases) { item in
                            Button { language = item.rawValue } label: {
                                HStack {
                                    Spacer()
                                    if language == item.rawValue { Image(systemName: "checkmark") }
                                    Text(item.name)
                                    Spacer()
                                }.padding(.vertical, 8)
                            }.buttonStyle(.bordered)
                        }
                        Button { selected = true } label: {
                            Text("Continue").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent)
                    }.padding(24)
                }
            }
        }.tint(Color(red: 0.384, green: 0.294, blue: 0.620))
    }
}
struct LanguageSettingsPicker: View {
    @AppStorage("appLanguage") private var language = "en"
    var body: some View {
        Picker("Language", selection: $language) {
            ForEach(AppLanguage.allCases) { item in Text(item.name).tag(item.rawValue) }
        }
    }
}
