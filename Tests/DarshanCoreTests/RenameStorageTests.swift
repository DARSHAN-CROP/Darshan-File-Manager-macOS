import XCTest
@testable import DarshanCore

final class RenameStorageTests: TempTestCase {
    func testBaseNameNumbering() throws {
        try make("IMG_1.jpg"); try make("IMG_2.jpg"); try make("IMG_10.JPG"); try make("note.txt")
        var o = RenameOptions(); o.extensions = "jpg"; o.baseName = "Photo"; o.numbering = true
        let plan = Renamer.plan(Scanner.scan(root), o)
        XCTAssertEqual(plan.map { $0.newName }, ["Photo_001.jpg", "Photo_002.jpg", "Photo_003.JPG"])
        XCTAssertEqual(plan.map { $0.oldName }, ["IMG_1.jpg", "IMG_2.jpg", "IMG_10.JPG"])   // natural order
    }

    func testPrefixSuffixFindReplace() throws {
        try make("holiday_beach.png")
        var o = RenameOptions(); o.prefix = "2026_"; o.suffix = "_final"; o.find = "holiday"; o.replace = "trip"
        XCTAssertEqual(Renamer.plan(Scanner.scan(root), o).map { $0.newName }, ["2026_trip_beach_final.png"])
    }

    func testFiltersByNameAndExtension() throws {
        try make("report1.pdf"); try make("report2.docx"); try make("photo.pdf")
        var o = RenameOptions(); o.nameContains = "report"; o.extensions = "pdf"; o.prefix = "X_"
        XCTAssertEqual(Renamer.plan(Scanner.scan(root), o).map { $0.newName }, ["X_report1.pdf"])
    }

    func testStartNumberAndDigits() throws {
        try make("a.txt"); try make("b.txt")
        var o = RenameOptions(); o.baseName = "Doc"; o.numbering = true; o.startNumber = 7; o.digits = 2
        XCTAssertEqual(Renamer.plan(Scanner.scan(root), o).map { $0.newName }, ["Doc_07.txt", "Doc_08.txt"])
    }

    func testUnchangedNamesAreSkippedAndPreviewDoesNotTouchDisk() throws {
        try make("a.txt")
        XCTAssertEqual(Renamer.plan(Scanner.scan(root), RenameOptions()).count, 0)
        var o = RenameOptions(); o.prefix = "p_"
        _ = Renamer.plan(Scanner.scan(root), o)
        XCTAssertEqual(names(), ["a.txt"])
    }

    func testApplyAndUndo() throws {
        try make("one.jpg", "1"); try make("two.jpg", "2")
        var o = RenameOptions(); o.baseName = "Photo"; o.numbering = true
        let plan = Renamer.plan(Scanner.scan(root), o)
        let op = Executor.apply(Renamer.moves(plan), title: "rename")
        XCTAssertEqual(op.count, 2)
        XCTAssertEqual(names(), ["Photo_001.jpg", "Photo_002.jpg"])
        XCTAssertEqual(Executor.undo(op), 2)
        XCTAssertEqual(names(), ["one.jpg", "two.jpg"])
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("one.jpg")), "1")
    }

    func testRenameNeverOverwritesExisting() throws {
        try make("Photo_001.jpg", "keep"); try make("z.jpg", "new")
        var o = RenameOptions(); o.nameContains = "z"; o.baseName = "Photo"; o.numbering = true
        Executor.apply(Renamer.moves(Renamer.plan(Scanner.scan(root), o)), title: "r")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Photo_001.jpg")), "keep")
        XCTAssertEqual(names(), ["Photo_001 (1).jpg", "Photo_001.jpg"])
    }

    func testIllegalCharactersRemoved() throws {
        try make("a.txt")
        var o = RenameOptions(); o.prefix = "a/b:"
        XCTAssertEqual(Renamer.plan(Scanner.scan(root), o).first?.newName, "ab" + "a.txt")
    }

    // MARK: storage

    func testStorageTotalsPerCategory() throws {
        try make("a.jpg", "12345"); try make("b.png", "123"); try make("c.mp4", String(repeating: "v", count: 100))
        try make("d.pdf", "pdf"); try make("sub/e.pdf", "pdfpdf"); try make("f.xyz", "o")
        let u = StorageStats.usage(in: root, recursive: true)
        XCTAssertEqual(u.first?.category, .videos)
        let map = Dictionary(uniqueKeysWithValues: u.map { ($0.category, $0) })
        XCTAssertEqual(map[.images]?.count, 2); XCTAssertEqual(map[.images]?.bytes, 8)
        XCTAssertEqual(map[.documents]?.count, 2); XCTAssertEqual(map[.documents]?.bytes, 9)
        XCTAssertEqual(map[.others]?.count, 1)
        XCTAssertNil(map[.audio])
        let t = StorageStats.total(u)
        XCTAssertEqual(t.count, 6); XCTAssertEqual(t.bytes, 8 + 100 + 9 + 1)
    }

    func testStorageNonRecursive() throws {
        try make("a.jpg", "1"); try make("sub/b.jpg", "22")
        XCTAssertEqual(StorageStats.total(StorageStats.usage(in: root, recursive: false)).count, 1)
    }

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(0), "0 B"); XCTAssertEqual(formatBytes(1023), "1023 B")
        XCTAssertEqual(formatBytes(1024), "1.0 KB"); XCTAssertEqual(formatBytes(5 * 1024 * 1024 + 512 * 1024), "5.5 MB")
    }
}
