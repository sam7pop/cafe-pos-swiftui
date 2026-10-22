import SwiftUI
#if os(macOS)
import AppKit
#endif

/// لغة التطبيق: عربي أو إنجليزي
enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }
    var nativeName: String { self == .arabic ? "العربية" : "English" }

    /// اللغة اللي التطبيق شغال بيها دلوقتي
    static var current: AppLanguage {
        let first = Locale.preferredLanguages.first ?? "ar"
        return first.hasPrefix("en") ? .english : .arabic
    }
    static var isArabic: Bool { current == .arabic }

    /// تنسيق الأرقام والتواريخ: العربي بأرقام إنجليزي عشان تبقى متناسقة
    var locale: Locale {
        self == .arabic ? Locale(identifier: "ar_EG@numbers=latn") : Locale(identifier: "en_US")
    }
    var layoutDirection: LayoutDirection { self == .arabic ? .rightToLeft : .leftToRight }

    /// بيحفظ اللغة المختارة. بتتطبق لما التطبيق يتقفل ويتفتح تاني،
    /// عشان الاتجاه (يمين أو شمال) يتظبط صح في الشاشة كلها.
    static func choose(_ lang: AppLanguage) {
        let d = UserDefaults.standard
        d.set([lang.rawValue], forKey: "AppleLanguages")
        if lang == .arabic {
            d.set(true, forKey: "NSForceRightToLeftWritingDirection")
            d.set(true, forKey: "AppleTextDirection")
        } else {
            d.removeObject(forKey: "NSForceRightToLeftWritingDirection")
            d.removeObject(forKey: "AppleTextDirection")
        }
    }
}

/// ترجمة سريعة: tr("عربي", "English")
func tr(_ arabic: String, _ english: String) -> String {
    AppLanguage.isArabic ? arabic : english
}

/// الوقت بشكل قصير حسب اللغة
func timeText(_ date: Date) -> String {
    date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLanguage.current.locale))
}

// MARK: - زرار تغيير اللغة
struct LanguageSwitcher: View {
    @State private var chosen = AppLanguage.current
    @State private var needsRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(tr("اللغة", "Language"), selection: $chosen) {
                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: chosen) { _, new in
                AppLanguage.choose(new)
                needsRestart = new != AppLanguage.current
            }

            if needsRestart {
                Text(chosen == .arabic ? "اقفل التطبيق وافتحه تاني عشان اللغة تتغير."
                                       : "Quit and reopen the app to switch the language.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                #if os(macOS)
                Button(chosen == .arabic ? "قفل التطبيق" : "Quit app") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                #endif
            }
        }
    }
}
