import ClipCore
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case turkish = "tr"

    var id: Self { self }

    /// The language's own name, as language pickers show it.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    var locale: Locale {
        Locale(identifier: self == .english ? "en_US" : "tr_TR")
    }

    /// Turkish when the Mac's first language is Turkish, English otherwise.
    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
    }
}

/// The language chosen in the settings. Switching it changes every text at once.
@MainActor
final class LanguageSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    private static let key = "language"

    init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .systemDefault
    }

    var strings: Strings { Strings(language: language) }
}

/// Every text the app shows, in English and Turkish side by side.
struct Strings: Sendable {
    let language: AppLanguage

    var locale: Locale { language.locale }

    private func t(_ english: String, _ turkish: String) -> String {
        language == .turkish ? turkish : english
    }

    /// "1 item", "2 items"; in Turkish the noun stays singular after a number ("2 öğe").
    private func count(_ number: Int, _ one: String, _ other: String, _ turkish: String) -> String {
        language == .turkish ? "\(number) \(turkish)" : "\(number) \(number == 1 ? one : other)"
    }

    // MARK: Categories and items

    func categoryName(_ category: ClipCategory) -> String {
        switch category {
        case .text: t("Text", "Metin")
        case .link: t("Link", "Bağlantı")
        case .image: t("Image", "Görsel")
        case .file: t("File", "Dosya")
        case .screenshot: t("Screenshot", "Ekran görüntüsü")
        }
    }

    /// The filter tab: "All" for nil.
    func categoryTitle(_ category: ClipCategory?) -> String {
        switch category {
        case nil: t("All", "Tümü")
        case .text: t("Text", "Metin")
        case .link: t("Links", "Bağlantılar")
        case .image: t("Images", "Görseller")
        case .file: t("Files", "Dosyalar")
        case .screenshot: t("Screenshots", "Ekran görüntüleri")
        }
    }

    /// The list label: the text or file names, or "Image 800 × 600" for an image without either.
    func title(of item: ClipItem) -> String {
        let hasText = item.text != nil && (item.category == .text || item.category == .link)
        guard !hasText, item.fileNames.isEmpty else { return item.title }
        return [categoryName(item.category), item.pixelSizeDescription].compactMap { $0 }.joined(separator: " ")
    }

    func relativeDate(_ date: Date) -> String {
        var style = Date.RelativeFormatStyle(presentation: .named)
        style.locale = locale
        return date.formatted(style)
    }

    func dateAndTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))
    }

    // MARK: Popup

    var searchPlaceholder: String { t("Search copied items", "Kopyalananlarda ara") }
    var clearSearch: String { t("Clear search", "Aramayı temizle") }
    var settings: String { t("Settings", "Ayarlar") }
    var settingsHelp: String { t("Settings (⌘,)", "Ayarlar (⌘,)") }
    var history: String { t("History", "Geçmiş") }
    var backToHistory: String { t("Back to the history (esc)", "Geçmişe dön (esc)") }
    func contains(_ query: String) -> String { t("Contains “\(query)”", "“\(query)” geçenler") }
    func similar(to query: String) -> String { t("Similar to “\(query)”", "“\(query)” kelimesine benzeyenler") }
    var nothingCopied: String { t("Nothing copied yet", "Henüz bir şey kopyalanmadı") }
    func noMatches(_ query: String) -> String { t("No matches for “\(query)”", "“\(query)” için sonuç yok") }
    var hintSelect: String { t("Select", "Seç") }
    var hintPaste: String { t("Paste", "Yapıştır") }
    var hintCopy: String { t("Copy", "Kopyala") }
    var hintCategory: String { t("Category", "Kategori") }
    var hintDelete: String { t("Delete", "Sil") }
    var hintClose: String { t("Close", "Kapat") }
    var allowAutoPaste: String { t("Allow auto-paste…", "Otomatik yapıştırmaya izin ver…") }
    var allowAutoPasteHelp: String {
        t(
            "↩ pastes into the app you were in once Clip History may control the keyboard (Accessibility).",
            "Clip History klavyeyi kontrol edebildiğinde (Erişilebilirlik) ↩, öğeyi önceki uygulamaya yapıştırır."
        )
    }

    // MARK: Preview

    var selectToPreview: String { t("Select an item to preview it", "Önizlemek için bir öğe seçin") }
    var openLink: String { t("Open Link", "Bağlantıyı Aç") }
    var found: String { t("Found", "Bulunan") }
    var type: String { t("Type", "Tür") }
    var copiedFrom: String { t("Copied from", "Kaynak") }
    var copied: String { t("Copied", "Kopyalanma") }
    var size: String { t("Size", "Boyut") }
    var length: String { t("Length", "Uzunluk") }
    var file: String { t("File", "Dosya") }

    func lengthValue(characters: Int, lines: Int) -> String {
        count(characters, "character", "characters", "karakter") + ", " + count(lines, "line", "lines", "satır")
    }

    /// "3 matches: developed, operation, Read (typo)"
    func matchesSummary(_ matches: Int, words: [String]) -> String {
        count(matches, "match", "matches", "eşleşme") + ": " + words.joined(separator: ", ")
    }

    func typo(_ word: String) -> String { t("\(word) (typo)", "\(word) (yazım hatası)") }
    func more(_ number: Int) -> String { t("+\(number) more", "+\(number) daha") }

    // MARK: Settings

    var general: String { t("General", "Genel") }
    var languageLabel: String { t("Language", "Dil") }
    var openAtLogin: String { t("Open Clip History when you log in", "Oturum açınca Clip History'yi aç") }
    var allowLoginItem: String {
        t("Allow Clip History in Login Items to finish.", "Tamamlamak için Giriş Öğeleri'nde Clip History'ye izin verin.")
    }
    var openLoginItems: String { t("Open Login Items", "Giriş Öğeleri'ni Aç") }

    var search: String { t("Search", "Arama") }
    var fullText: String { t("Full text", "Tam metin") }
    var fuzzy: String { t("Fuzzy, forgives typos", "Esnek, yazım hatalarını tolere eder") }
    var fuzzyFooter: String {
        t(
            "Finds words with a typo too: “raed” or “red” finds “read”. Items with the words as typed are listed first, whole words before parts of words.",
            "Yazım hatalı kelimeleri de bulur: “raed” ya da “red” yazınca “read” bulunur. Kelimeleri yazıldığı gibi içerenler önce, tam kelimeler kelime parçalarından önce listelenir."
        )
    }
    var fullTextFooter: String {
        t(
            "Finds items that contain every word as typed. Case and accents are ignored.",
            "Her kelimeyi yazıldığı gibi içeren öğeleri bulur. Büyük/küçük harf ve aksanlar dikkate alınmaz."
        )
    }

    var keep: String { t("Keep", "Sakla") }
    var keepCount: String { t("The newest items, up to a number", "En yeni öğeler, belirli bir sayıya kadar") }
    var keepSize: String { t("The newest items, up to a size", "En yeni öğeler, belirli bir boyuta kadar") }
    var keepEverything: String { t("Everything", "Hepsi") }
    var items: String { t("Items", "Öğe sayısı") }
    var megabytes: String { t("Megabytes", "Megabayt") }
    var unlimitedWarning: String {
        t(
            "Nothing is removed. With thousands of items or many large images, opening and searching the history gets slower and it takes more disk space.",
            "Hiçbir şey silinmez. Binlerce öğe ya da çok sayıda büyük görsel olduğunda geçmişi açmak ve aramak yavaşlar, daha fazla disk alanı kullanılır."
        )
    }
    var expireToggle: String { t("Remove items older than a number of days", "Belirli bir günden eski öğeleri sil") }
    var days: String { t("Days", "Gün") }

    func usage(items: Int, size: String) -> String {
        t("Now ", "Şu an ") + count(items, "item", "items", "öğe") + ", \(size)."
    }

    var overLimit: String {
        t(
            "Over the limit: the oldest items are removed when you copy something new.",
            "Sınırın üzerinde: yeni bir şey kopyaladığınızda en eski öğeler silinir."
        )
    }
    var manyItems: String {
        t("That is a lot of items: a limit would keep the history fast.", "Bu çok fazla öğe: bir sınır geçmişi hızlı tutar.")
    }

    func expiryInfo(days: Int) -> String {
        t(
            "An item is removed \(count(days, "day", "days", "gün")) after it was last copied or pasted.",
            "Bir öğe, son kopyalanmasından ya da yapıştırılmasından \(days) gün sonra silinir."
        )
    }

    func expiredPending(_ items: Int) -> String {
        t(
            "\(items) \(items == 1 ? "item is" : "items are") older than that and will be removed within 10 minutes, or when you next open the history.",
            "\(items) öğe bundan daha eski; 10 dakika içinde ya da geçmişi bir sonraki açışınızda silinecek."
        )
    }

    var shortcut: String { t("Shortcut", "Kısayol") }
    var openHistoryShortcut: String { t("Open the history to paste", "Yapıştırmak için geçmişi aç") }
    var typeNewShortcut: String { t("Type the new shortcut…", "Yeni kısayolu girin…") }
    var escCancels: String { t("esc cancels", "esc iptal eder") }
    var clickThenPress: String { t("Click, then press the keys you want", "Tıklayın, sonra istediğiniz tuşlara basın") }
    var reset: String { t("Reset", "Sıfırla") }
    func backTo(_ shortcut: String) -> String { t("Back to \(shortcut)", "\(shortcut) kısayoluna dön") }
    var recordingFooter: String {
        t("Press the keys of the new shortcut, for example ⌥⌘V. esc cancels.", "Yeni kısayolun tuşlarına basın, örneğin ⌥⌘V. esc iptal eder.")
    }
    var shortcutFooter: String {
        t("Click the shortcut to change it. It works in every app.", "Değiştirmek için kısayola tıklayın. Her uygulamada çalışır.")
    }

    func shortcutError(_ error: ShortcutError) -> String {
        switch error {
        case .needsModifier(let shortcut):
            t("\(shortcut) would get in the way of typing. Add ⌘, ⌥ or ⌃.", "\(shortcut) yazmayı engeller. ⌘, ⌥ ya da ⌃ ekleyin.")
        case .taken(let shortcut):
            t(
                "Another app already uses \(shortcut). Choose a different shortcut.",
                "\(shortcut) başka bir uygulama tarafından kullanılıyor. Başka bir kısayol seçin."
            )
        }
    }

    // MARK: Menu bar and alerts

    var showHistory: String { t("Show History", "Geçmişi Göster") }
    var pauseRecording: String { t("Pause Recording", "Kaydı Duraklat") }
    var settingsMenu: String { t("Settings…", "Ayarlar…") }
    var allowAutoPasteMenu: String { t("Allow Auto-Paste…", "Otomatik Yapıştırmaya İzin Ver…") }
    var clearHistoryMenu: String { t("Clear History…", "Geçmişi Temizle…") }
    var quit: String { t("Quit Clip History", "Clip History'den Çık") }
    var clearHistoryQuestion: String { t("Clear the clipboard history?", "Pano geçmişi temizlensin mi?") }

    func clearHistoryDetails(_ items: Int) -> String {
        t(
            "All \(count(items, "item", "items", "öğe")) are removed. Your screenshot files stay where they are.",
            "\(items) öğenin tamamı silinir. Ekran görüntüsü dosyalarınız yerinde kalır."
        )
    }

    var clearHistory: String { t("Clear History", "Geçmişi Temizle") }
    var cancel: String { t("Cancel", "Vazgeç") }
}

private struct StringsKey: EnvironmentKey {
    static let defaultValue = Strings(language: .english)
}

extension EnvironmentValues {
    /// The texts in the chosen language, set at the root of the popup.
    var strings: Strings {
        get { self[StringsKey.self] }
        set { self[StringsKey.self] = newValue }
    }
}
