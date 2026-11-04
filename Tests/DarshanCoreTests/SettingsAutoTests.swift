import XCTest
@testable import DarshanCore

final class SettingsAutoTests: TempTestCase {
    private func store() -> SettingsStore { SettingsStore(defaults: UserDefaults(suiteName: "dfm-test-" + UUID().uuidString)!) }

    // MARK: theme & language prefs
    func testDefaults() {
        let s = store().load()
        XCTAssertEqual(s.theme, .system); XCTAssertEqual(s.accent, .maroon); XCTAssertEqual(s.language, .english)
        XCTAssertTrue(s.auto.customRules); XCTAssertTrue(s.auto.sortByType)
        XCTAssertFalse(s.auto.sortByDate); XCTAssertFalse(s.auto.oldFiles); XCTAssertFalse(s.auto.duplicates); XCTAssertFalse(s.auto.enabled)
    }

    func testThemeAccentLanguagePersist() {
        let st = store(); var s = st.load()
        s.theme = .dark; s.accent = .gold; s.language = .gujarati; s.auto.oldFiles = true; s.auto.oldDays = 60
        st.save(s)
        let r = st.load()
        XCTAssertEqual(r.theme, .dark); XCTAssertEqual(r.accent, .gold); XCTAssertEqual(r.language, .gujarati)
        XCTAssertTrue(r.auto.oldFiles); XCTAssertEqual(r.auto.oldDays, 60)
    }

    func testOldSettingsJSONStillLoads() {
        let suite = UserDefaults(suiteName: "dfm-old-" + UUID().uuidString)!
        suite.set(Data("{\"theme\":\"light\"}".utf8), forKey: "darshan.settings.v1")
        let s = SettingsStore(defaults: suite).load()
        XCTAssertEqual(s.theme, .light); XCTAssertEqual(s.accent, .maroon); XCTAssertTrue(s.auto.sortByType)
    }

    func testSystemThemeFollowsOS() {
        XCTAssertTrue(ThemeMode.system.isDark(systemIsDark: true))
        XCTAssertFalse(ThemeMode.system.isDark(systemIsDark: false))
        XCTAssertFalse(ThemeMode.light.isDark(systemIsDark: true))
        XCTAssertTrue(ThemeMode.dark.isDark(systemIsDark: false))
    }

    func testInkKeepsBrandHueWhenAlreadyReadable() {
        XCTAssertEqual(Accent.maroon.inkHex(dark: false), "7B1E3A")
        XCTAssertNotEqual(Accent.gold.inkHex(dark: false), "F7B500")      // gold text on white would be unreadable
    }

    func testBrandAccents() {
        XCTAssertEqual(Accent.maroon.hex(dark: false), "7B1E3A")
        XCTAssertEqual(Accent.gold.hex(dark: false), "F7B500")
        XCTAssertEqual(Accent.allCases.count, 6)
    }

    func testContrastAllAccentsAndPalettes() {
        for dark in [false, true] {
            let p = Palette.of(dark: dark)
            XCTAssertGreaterThan(Contrast.ratio(p.text, p.background), 7)
            XCTAssertGreaterThan(Contrast.ratio(p.text, p.surface), 7)
            XCTAssertGreaterThan(Contrast.ratio(p.secondaryText, p.background), 4.5)
            XCTAssertGreaterThan(Contrast.ratio(p.secondaryText, p.surface), 4.5)
            for a in Accent.allCases {
                // text on a button filled with the accent
                XCTAssertGreaterThanOrEqual(Contrast.ratio(a.hex(dark: dark), a.onAccentHex(dark: dark)), 4.5, "\(a) dark=\(dark)")
                // the button must stand out from the card it sits on
                XCTAssertGreaterThanOrEqual(Contrast.ratio(a.hex(dark: dark), p.surface), dark ? 2.5 : 1.5, "\(a) fill vs surface dark=\(dark)")
                // accent "ink" for text/highlights on the page background and on cards
                XCTAssertGreaterThanOrEqual(Contrast.ratio(a.inkHex(dark: dark), p.background), 4.5, "\(a) ink bg dark=\(dark)")
                XCTAssertGreaterThanOrEqual(Contrast.ratio(a.inkHex(dark: dark), p.surface), 4.5, "\(a) ink surface dark=\(dark)")
            }
        }
        XCTAssertEqual(Accent.gold.onAccentHex(dark: false), "000000")   // dark text on gold
        XCTAssertEqual(Accent.maroon.onAccentHex(dark: false), "FFFFFF")
    }

    func testLanguageSwitch() {
        for key in ["tab_sort", "sort_by_type", "undo_last", "settings_language"] {
            let en = L.t(key, .english), gu = L.t(key, .gujarati)
            XCTAssertNotEqual(en, gu, key)
            XCTAssertNotEqual(en, key)
        }
        XCTAssertEqual(L.t("tab_sort", .gujarati), "સૉર્ટ")
        XCTAssertEqual(L.t("moved_n", .english, ["5"]), "5 files moved")
        XCTAssertEqual(L.t("old_preview", .english, ["3", "1.0 KB", "30"]), "3 files (1.0 KB) not modified for 30 days")
        XCTAssertEqual(L.t("nope", .gujarati), "nope")
    }

    func testEveryStringHasGujaratiAndMatchingPlaceholders() {
        let gujarati = CharacterSet(charactersIn: "\u{0A80}"..."\u{0AFF}")
        for k in L.allKeys {
            let e = L.raw(k)!
            XCTAssertFalse(e.en.isEmpty, k); XCTAssertFalse(e.gu.isEmpty, k)
            for p in ["{0}", "{1}", "{2}"] { XCTAssertEqual(e.en.contains(p), e.gu.contains(p), "\(k) \(p)") }
            if k != "app_title" || true { XCTAssertNotNil(e.gu.rangeOfCharacter(from: gujarati), "no Gujarati letters in \(k)") }
        }
        for c in Category.allCases { XCTAssertNotEqual(L.category(c, .english), L.category(c, .gujarati)) }
        for a in Accent.allCases { XCTAssertNotEqual(L.accent(a, .english), L.accent(a, .gujarati)) }
    }

    // MARK: auto mode
    func testAutoSummaryText() {
        var s = AutoSummary(); s.sorted = 12; s.duplicatesMoved = 3; s.oldMoved = 5
        XCTAssertEqual(s.text(.english), "12 sorted, 3 duplicates moved, 5 old files moved")
        XCTAssertEqual(s.text(.gujarati), "12 સૉર્ટ થયા, 3 ડુપ્લિકેટ ખસેડ્યા, 5 જૂની ફાઇલો ખસેડી")
        var t = AutoSummary(); t.sorted = 4
        XCTAssertEqual(t.text(.english), "4 sorted")
        XCTAssertEqual(AutoSummary().text(.english), "Nothing to do")
    }

    func testAutoDefaultRunsRulesThenTypeOnly() throws {
        try make("trip.jpg"); try make("a.pdf"); try make("old.txt", daysOld: 200); try make("d1.bin", "same"); try make("d2.bin", "same")
        var s = AppSettings(); s.rules = [Rule(kind: .extensions, value: "jpg", folder: "Trips")]
        let r = AutoRunner.run(folder: root, settings: s)
        XCTAssertEqual(r.sorted, 5); XCTAssertEqual(r.duplicatesMoved, 0); XCTAssertEqual(r.oldMoved, 0)
        XCTAssertTrue(exists("Trips/trip.jpg")); XCTAssertTrue(exists("Documents/a.pdf")); XCTAssertTrue(exists("Documents/old.txt"))
        XCTAssertTrue(exists("Others/d1.bin")); XCTAssertTrue(exists("Others/d2.bin"))   // duplicates untouched by default
        XCTAssertFalse(exists("Duplicates")); XCTAssertFalse(exists("Old Files"))
    }

    func testAutoAllActionsAndSummary() throws {
        try make("keep.dat", "dupdata", daysOld: 20); try make("copy1.dat", "dupdata", daysOld: 5); try make("copy2.dat", "dupdata", daysOld: 4)
        try make("ancient1.txt", "a1", daysOld: 400); try make("ancient2.txt", "a2", daysOld: 300)
        try make("fresh.jpg", "f", daysOld: 1)
        var s = AppSettings()
        s.auto.duplicates = true; s.auto.oldFiles = true; s.auto.oldDays = 90; s.auto.sortByType = true
        let r = AutoRunner.run(folder: root, settings: s)
        XCTAssertEqual(r.duplicatesMoved, 2); XCTAssertEqual(r.oldMoved, 2); XCTAssertEqual(r.sorted, 2)   // keep.dat + fresh.jpg
        XCTAssertEqual(r.text(.english), "2 sorted, 2 duplicates moved, 2 old files moved")
        XCTAssertEqual(names("Duplicates"), ["copy1.dat", "copy2.dat"])
        XCTAssertEqual(names("Old Files"), ["ancient1.txt", "ancient2.txt"])
        XCTAssertTrue(exists("Others/keep.dat")); XCTAssertTrue(exists("Images/fresh.jpg"))
    }

    func testAutoDateSortAndExtensionChoice() throws {
        try make("a.jpg", "1"); try make("b.pdf", "2")
        var s = AppSettings(); s.auto.sortByType = false; s.auto.sortByExtension = true; s.auto.sortByDate = false
        _ = AutoRunner.run(folder: root, settings: s)
        XCTAssertTrue(exists("JPG/a.jpg")); XCTAssertTrue(exists("PDF/b.pdf"))
        try make("c.txt", "3")
        var d = AppSettings(); d.auto.sortByType = false; d.auto.sortByDate = true
        let r = AutoRunner.run(folder: root, settings: d)
        XCTAssertEqual(r.sorted, 1)
        let year = String(Calendar(identifier: .gregorian).component(.year, from: Date()))
        XCTAssertTrue(names(year).count == 1)
    }

    func testAutoDisabledOptionsDoNothing() throws {
        try make("a.jpg")
        var s = AppSettings(); s.auto = AutoOptions(); s.auto.customRules = false; s.auto.sortByType = false
        let r = AutoRunner.run(folder: root, settings: s)
        XCTAssertEqual(r.total, 0); XCTAssertTrue(exists("a.jpg"))
    }

    func testAutoOperationsAreJournaledAndUndoable() throws {
        try make("a.jpg"); try make("b.pdf")
        let j = Journal()
        let r = AutoRunner.run(folder: root, settings: AppSettings(), journal: j)
        XCTAssertEqual(r.total, 2); XCTAssertEqual(j.operations.count, 1)
        j.undoLast()
        XCTAssertEqual(names(), ["a.jpg", "b.pdf"])
    }

    func testAutoRefusesSystemFolders() {
        XCTAssertFalse(AutoRunner.isSafeFolder(URL(fileURLWithPath: "/")))
        XCTAssertFalse(AutoRunner.isSafeFolder(URL(fileURLWithPath: "/System")))
        XCTAssertFalse(AutoRunner.isSafeFolder(URL(fileURLWithPath: "/usr")))
        XCTAssertTrue(AutoRunner.isSafeFolder(URL(fileURLWithPath: "/Users/darshan/Downloads")))
        XCTAssertEqual(AutoRunner.run(folder: URL(fileURLWithPath: "/"), settings: AppSettings()).total, 0)
    }
}
