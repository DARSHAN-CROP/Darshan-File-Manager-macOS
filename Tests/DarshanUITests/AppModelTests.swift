#if canImport(SwiftUI)
import XCTest
import Foundation
import DarshanCore
@testable import DarshanUI

@MainActor
final class AppModelTests: XCTestCase {
    var dir: URL!
    let fm = FileManager.default

    override func setUp() async throws {
        dir = fm.temporaryDirectory.appendingPathComponent("darshan-ui-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try? fm.removeItem(at: dir) }

    private func newStore() -> SettingsStore { SettingsStore(defaults: UserDefaults(suiteName: "dfm-ui-" + UUID().uuidString)!) }
    private func write(_ name: String, _ text: String = "x", daysOld: Double = 0) throws {
        let u = dir.appendingPathComponent(name)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: u, atomically: true, encoding: .utf8)
        if daysOld > 0 { try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-daysOld * 86_400)], ofItemAtPath: u.path) }
    }
    private func exists(_ p: String) -> Bool { fm.fileExists(atPath: dir.appendingPathComponent(p).path) }

    func testThemeAccentLanguagePersistAcrossLaunches() {
        let store = newStore()
        let a = AppModel(store: store, journalURL: nil)
        XCTAssertEqual(a.settings.theme, .system); XCTAssertEqual(a.settings.accent, .maroon)
        a.settings.theme = .dark; a.settings.accent = .gold; a.settings.language = .gujarati
        let b = AppModel(store: store, journalURL: nil)
        XCTAssertEqual(b.settings.theme, .dark); XCTAssertEqual(b.settings.accent, .gold); XCTAssertEqual(b.lang, .gujarati)
        XCTAssertEqual(b.t("tab_sort"), "સૉર્ટ")
        b.settings.language = .english
        XCTAssertEqual(b.t("tab_sort"), "Sort")          // switches immediately
    }

    func testAppThemeResolvesColours() {
        let light = AppTheme(dark: false, accent: .maroon), dark = AppTheme(dark: true, accent: .gold)
        XCTAssertFalse(light.dark); XCTAssertTrue(dark.dark)
        XCTAssertEqual(light.accentChoice, .maroon)
    }

    func testSortThenUndo() async throws {
        try write("a.jpg"); try write("b.pdf")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        await m.sort(.type)
        XCTAssertTrue(exists("Images/a.jpg")); XCTAssertTrue(exists("Documents/b.pdf"))
        XCTAssertTrue(m.canUndo)
        await m.undo()
        XCTAssertTrue(exists("a.jpg")); XCTAssertTrue(exists("b.pdf")); XCTAssertFalse(m.canUndo)
    }

    func testRulesApplyFirstFromModel() async throws {
        try write("holiday.jpg"); try write("invoice.pdf")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        m.saveRule(Rule(kind: .nameContains, value: "invoice", folder: "Bills"))
        await m.sort(.type)
        XCTAssertTrue(exists("Bills/invoice.pdf")); XCTAssertTrue(exists("Images/holiday.jpg"))
        XCTAssertEqual(m.settings.rules.count, 1)
        m.deleteRule(m.settings.rules[0])
        XCTAssertTrue(m.settings.rules.isEmpty)
    }

    func testDuplicateScanSelectAndMove() async throws {
        try write("a.txt", "same", daysOld: 5); try write("b.txt", "same", daysOld: 1); try write("c.txt", "other")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        await m.scanDuplicates()
        XCTAssertEqual(m.duplicateGroups.count, 1)
        XCTAssertEqual(m.duplicateSelection.count, 1)
        await m.moveDuplicates()
        XCTAssertTrue(exists("a.txt")); XCTAssertTrue(exists("Duplicates/b.txt")); XCTAssertTrue(exists("c.txt"))
        await m.undo()
        XCTAssertTrue(exists("b.txt"))
    }

    func testOldFilesPreviewAndMove() async throws {
        try write("new.txt", daysOld: 1); try write("old.txt", daysOld: 200)
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        m.settings.oldDays = 90
        await m.previewOld()
        XCTAssertEqual(m.oldPreview.map { $0.name }, ["old.txt"])
        await m.moveOld()
        XCTAssertTrue(exists("Old Files/old.txt")); XCTAssertTrue(exists("new.txt"))
    }

    func testRenamePreviewApplyAndUndo() async throws {
        try write("x1.jpg"); try write("x2.jpg")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        m.renameOptions.baseName = "Photo"; m.renameOptions.numbering = true
        await m.previewRename()
        XCTAssertEqual(m.renamePreview.map { $0.newName }, ["Photo_001.jpg", "Photo_002.jpg"])
        await m.applyRename()
        XCTAssertTrue(exists("Photo_001.jpg")); XCTAssertTrue(exists("Photo_002.jpg"))
        await m.undo()
        XCTAssertTrue(exists("x1.jpg"))
    }

    func testStorageCalculation() async throws {
        try write("a.jpg", "12345"); try write("b.mp4", "1234567890")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        await m.calculateStorage()
        XCTAssertTrue(m.usageScanned)
        XCTAssertEqual(m.usage.first?.category, .videos)
    }

    func testAutoRunFromModelUsesTicks() async throws {
        try write("a.jpg"); try write("b.pdf"); try write("ancient.txt", daysOld: 400)
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        m.settings.auto.oldFiles = true; m.settings.auto.oldDays = 90; m.settings.auto.notify = false
        await m.runAuto()
        XCTAssertTrue(exists("Old Files/ancient.txt")); XCTAssertTrue(exists("Images/a.jpg")); XCTAssertTrue(exists("Documents/b.pdf"))
        XCTAssertTrue(m.status.contains("2 sorted"))
        XCTAssertTrue(m.status.contains("1 old files moved"))
    }

    func testRelativePathForDisplay() throws {
        try write("sub/deep/a.txt")
        let m = AppModel(store: newStore(), journalURL: nil)
        m.setFolder(dir)
        XCTAssertEqual(m.relativePath(dir.appendingPathComponent("sub/deep/a.txt")), "sub/deep/a.txt")
        XCTAssertEqual(m.relativePath(URL(fileURLWithPath: "/elsewhere/x.txt")), "x.txt")
    }

    func testNoFolderDoesNothing() async {
        let m = AppModel(store: newStore(), journalURL: nil)
        m.folder = nil
        await m.sort(.type)
        XCTAssertEqual(m.status, m.t("pick_first"))
    }

    func testDemoSampleFolderHasDuplicatesAndOldFiles() async {
        let m = DemoMode.makeModel()
        XCTAssertNotNil(m.folder)
        m.settings.includeSubfolders = true
        await m.scanDuplicates()
        XCTAssertGreaterThanOrEqual(m.duplicateGroups.count, 2)
        await m.previewOld()
        XCTAssertGreaterThan(m.oldPreview.count, 0)
    }
}
#endif
