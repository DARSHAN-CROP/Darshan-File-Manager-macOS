import XCTest
@testable import DarshanCore

final class DuplicatesTests: TempTestCase {
    func testSHA256KnownVectors() {
        XCTAssertEqual(Hashing.sha256Hex(of: Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(Hashing.sha256Hex(of: "abc".data(using: .utf8)!), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let long = String(repeating: "a", count: 1000).data(using: .utf8)!
        XCTAssertEqual(Hashing.sha256Hex(of: long), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }

    func testFileHashMatchesVector() throws {
        let u = try make("abc.txt", "abc")
        XCTAssertEqual(Hashing.sha256Hex(ofFile: u), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testGroupsBySizeThenHash() throws {
        try make("a.txt", "hello"); try make("b.txt", "hello"); try make("sub/c.txt", "hello")
        try make("d.txt", "world")          // same size, different content
        try make("e.txt", "unique-content")
        let groups = DuplicateFinder.find(in: root, recursive: true)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].files.count, 3)
        XCTAssertEqual(groups[0].size, 5)
        XCTAssertEqual(groups[0].wastedBytes, 10)
        XCTAssertEqual(DuplicateFinder.totalWasted(groups), 10)
    }

    func testNonRecursiveIgnoresSubfolders() throws {
        try make("a.txt", "hello"); try make("sub/b.txt", "hello")
        XCTAssertEqual(DuplicateFinder.find(in: root, recursive: false).count, 0)
        XCTAssertEqual(DuplicateFinder.find(in: root, recursive: true).count, 1)
    }

    func testEmptyFilesAreNotDuplicates() throws {
        try make("a.txt", ""); try make("b.txt", "")
        XCTAssertEqual(DuplicateFinder.find(in: root).count, 0)
    }

    func testOriginalIsOldest() throws {
        try make("new.txt", "same", daysOld: 1); try make("old.txt", "same", daysOld: 50)
        let g = DuplicateFinder.find(in: root)[0]
        XCTAssertEqual(g.original.name, "old.txt")
        XCTAssertEqual(g.copies.map { $0.name }, ["new.txt"])
    }

    func testMoveDuplicatesNeverDeletesAndUndoes() throws {
        try make("a.txt", "dup-data", daysOld: 10); try make("b.txt", "dup-data", daysOld: 5); try make("c.txt", "dup-data", daysOld: 1)
        let groups = DuplicateFinder.find(in: root)
        let files = DuplicateFinder.filesToMove(groups: groups, selected: DuplicateFinder.defaultSelection(groups))
        XCTAssertEqual(files.count, 2)
        let op = Executor.apply(Planner.moveDuplicates(files, root: root), title: "dups")
        XCTAssertEqual(op.count, 2)
        XCTAssertTrue(exists("a.txt"))
        XCTAssertEqual(names("Duplicates"), ["b.txt", "c.txt"])           // moved, not deleted
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Duplicates/b.txt")), "dup-data")
        Executor.undo(op)
        XCTAssertEqual(names(), ["a.txt", "b.txt", "c.txt"])
    }

    func testSelectingEveryFileStillKeepsOne() throws {
        try make("a.txt", "dd", daysOld: 9); try make("b.txt", "dd", daysOld: 1)
        let groups = DuplicateFinder.find(in: root)
        let all = Set(groups[0].files.map { $0.id })
        let files = DuplicateFinder.filesToMove(groups: groups, selected: all)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].name, "b.txt")
    }

    func testUserCanChooseWhichCopyToMove() throws {
        try make("a.txt", "dd", daysOld: 9); try make("b.txt", "dd", daysOld: 5); try make("c.txt", "dd", daysOld: 1)
        let groups = DuplicateFinder.find(in: root)
        let pick = groups[0].files.first { $0.name == "c.txt" }!
        let files = DuplicateFinder.filesToMove(groups: groups, selected: [pick.id])
        XCTAssertEqual(files.map { $0.name }, ["c.txt"])
    }

    func testDuplicatesFolderSkippedOnRescan() throws {
        try make("a.txt", "zz", daysOld: 3); try make("b.txt", "zz", daysOld: 1)
        let g = DuplicateFinder.find(in: root)
        Executor.apply(Planner.moveDuplicates(DuplicateFinder.filesToMove(groups: g, selected: DuplicateFinder.defaultSelection(g)), root: root), title: "d")
        XCTAssertEqual(DuplicateFinder.find(in: root).count, 0)
    }
}
