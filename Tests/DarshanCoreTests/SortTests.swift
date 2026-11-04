import XCTest
@testable import DarshanCore

final class SortTests: TempTestCase {
    func testCategoryMap() {
        XCTAssertEqual(Category.of(ext: "JPG"), .images)
        XCTAssertEqual(Category.of(ext: "mp4"), .videos)
        XCTAssertEqual(Category.of(ext: "mp3"), .audio)
        XCTAssertEqual(Category.of(ext: "pdf"), .documents)
        XCTAssertEqual(Category.of(ext: "zip"), .archives)
        XCTAssertEqual(Category.of(ext: "swift"), .code)
        XCTAssertEqual(Category.of(ext: "xyz"), .others)
        XCTAssertEqual(Category.of(ext: ""), .others)
    }

    func testDoubleExtension() {
        XCTAssertEqual(FileItem.extensionOf("backup.tar.gz"), "tar.gz")
        XCTAssertEqual(FileItem.extensionOf("Photo.JPG"), "jpg")
        XCTAssertEqual(FileItem.extensionOf("README"), "")
        XCTAssertEqual(FileItem.extensionOf(".hidden"), "")
    }

    func testScannerSkipsHiddenTempAndFolders() throws {
        try make("a.jpg"); try make(".DS_Store"); try make("movie.mp4.crdownload"); try make("sub/b.txt")
        let top = Scanner.scan(root)
        XCTAssertEqual(top.map { $0.name }, ["a.jpg"])
        let all = Scanner.scan(root, recursive: true)
        XCTAssertEqual(Set(all.map { $0.name }), ["a.jpg", "b.txt"])
    }

    func testSortByType() throws {
        try make("a.jpg"); try make("b.mp4"); try make("c.pdf"); try make("d.zip"); try make("e.weird"); try make("f.swift"); try make("g.mp3")
        let plan = Planner.byType(Scanner.scan(root), root: root)
        let op = Executor.apply(plan, title: "t")
        XCTAssertEqual(op.count, 7)
        XCTAssertTrue(exists("Images/a.jpg")); XCTAssertTrue(exists("Videos/b.mp4")); XCTAssertTrue(exists("Documents/c.pdf"))
        XCTAssertTrue(exists("Archives/d.zip")); XCTAssertTrue(exists("Others/e.weird")); XCTAssertTrue(exists("Code/f.swift")); XCTAssertTrue(exists("Audio/g.mp3"))
        XCTAssertFalse(exists("a.jpg"))
    }

    func testSortByExtension() throws {
        try make("a.jpg"); try make("b.JPG"); try make("noext"); try make("c.tar.gz")
        Executor.apply(Planner.byExtension(Scanner.scan(root), root: root), title: "t")
        XCTAssertTrue(exists("JPG/a.jpg")); XCTAssertTrue(exists("JPG/b.JPG"))
        XCTAssertTrue(exists("NO_EXTENSION/noext")); XCTAssertTrue(exists("TAR_GZ/c.tar.gz"))
    }

    func testNeverOverwrites() throws {
        try make("Images/a.jpg", "old"); try make("a.jpg", "new")
        let op = Executor.apply(Planner.byType(Scanner.scan(root), root: root), title: "t")
        XCTAssertEqual(op.count, 1)
        XCTAssertEqual(names("Images"), ["a (1).jpg", "a.jpg"])
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Images/a.jpg")), "old")
    }

    func testUndoRestoresAndRemovesCreatedFolders() throws {
        try make("a.jpg"); try make("b.pdf")
        let op = Executor.apply(Planner.byType(Scanner.scan(root), root: root), title: "t")
        XCTAssertTrue(exists("Images"))
        XCTAssertEqual(Executor.undo(op), 2)
        XCTAssertEqual(names(), ["a.jpg", "b.pdf"])
        XCTAssertFalse(exists("Images")); XCTAssertFalse(exists("Documents"))
    }

    func testUndoKeepsPreexistingFolders() throws {
        try make("Images/old.png"); try make("a.jpg")
        let op = Executor.apply(Planner.byType(Scanner.scan(root), root: root), title: "t")
        Executor.undo(op)
        XCTAssertTrue(exists("Images/old.png")); XCTAssertTrue(exists("a.jpg"))
    }

    func testJournalPersistsAndUndoesNewestFirst() throws {
        let jurl = root.appendingPathComponent(".journal/j.json")
        let j = Journal(fileURL: jurl)
        try make("a.jpg")
        j.push(Executor.apply(Planner.byType(Scanner.scan(root), root: root), title: "one"))
        let j2 = Journal(fileURL: jurl)                       // reload from disk
        XCTAssertEqual(j2.operations.count, 1)
        XCTAssertEqual(j2.last?.title, "one")
        let r = j2.undoLast()
        XCTAssertEqual(r?.1, 1)
        XCTAssertTrue(exists("a.jpg"))
        XCTAssertNil(j2.undoLast())
        XCTAssertEqual(Journal(fileURL: jurl).operations.count, 0)
    }

    func testEmptyOperationNotJournaled() {
        let j = Journal()
        j.push(Executor.apply([], title: "none"))
        XCTAssertTrue(j.operations.isEmpty)
    }

    func testUniqueURLNoExtension() throws {
        try make("x"); 
        XCTAssertEqual(Executor.uniqueURL(root.appendingPathComponent("x")).lastPathComponent, "x (1)")
    }
}
