import ClipCore
import Foundation
import Testing
@testable import ClipHistory

struct StringsTests {
    let english = Strings(language: .english)
    let turkish = Strings(language: .turkish)

    @Test func countsWithEnglishPluralsAndTurkishSingulars() {
        #expect(english.lengthValue(characters: 1, lines: 2) == "1 character, 2 lines")
        #expect(turkish.lengthValue(characters: 1, lines: 2) == "1 karakter, 2 satır")
        #expect(english.usage(items: 1, size: "4 KB") == "Now 1 item, 4 KB.")
        #expect(turkish.usage(items: 3, size: "4 KB") == "Şu an 3 öğe, 4 KB.")
    }

    @Test func formatsDatesInTheChosenLanguage() {
        // Two days back is "evvelsi gün" in Turkish, so five days shows the "… önce" form.
        let fiveDaysAgo = Date(timeIntervalSinceNow: -5 * 24 * 3600)
        #expect(english.relativeDate(fiveDaysAgo) == "5 days ago")
        #expect(turkish.relativeDate(fiveDaysAgo) == "5 gün önce")
    }

    @Test func namesEveryCategoryInBothLanguages() {
        for category in ClipCategory.allCases {
            #expect(english.categoryName(category) != turkish.categoryName(category))
            #expect(english.categoryTitle(category) != turkish.categoryTitle(category))
        }
        #expect(turkish.categoryTitle(nil) == "Tümü")
    }

    @Test func titlesImagesInTheChosenLanguage() {
        let image = ClipItem(category: .image, pixelWidth: 800, pixelHeight: 600, contentHash: "")
        #expect(english.title(of: image) == "Image 800 × 600")
        #expect(turkish.title(of: image) == "Görsel 800 × 600")
        let text = ClipItem(category: .text, text: "merhaba dünya", contentHash: "")
        #expect(turkish.title(of: text) == "merhaba dünya")
    }

    @Test func wordsShortcutErrors() {
        #expect(turkish.shortcutError(.taken("⌥⌘V")).hasPrefix("⌥⌘V başka bir uygulama"))
        #expect(english.shortcutError(.needsModifier("V")).hasPrefix("V would get in the way"))
    }
}
