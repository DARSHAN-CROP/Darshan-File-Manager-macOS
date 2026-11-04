import XCTest
@testable import DarshanCore

final class DateOldTests: TempTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testDateFolderNaming() {
        XCTAssertEqual(DateFolders.name(for: date(2026, 11, 4)), "2026/11-November")
        XCTAssertEqual(DateFolders.name(for: date(2025, 1, 31)), "2025/01-January")
        XCTAssertEqual(DateFolders.name(for: date(2024, 9, 1)), "2024/09-September")
        XCTAssertEqual(DateFolders.name(for: date(2023, 12, 15)), "2023/12-December")
    }

    func testSortByDateMovesAndUndoes() throws {
        let a = try make("a.txt"); let b = try make("b.txt")
        try fm.setAttributes([.modificationDate: date(2025, 3, 10)], ofItemAtPath: a.path)
        try fm.setAttributes([.modificationDate: date(2026, 11, 4)], ofItemAtPath: b.path)
        let op = Executor.apply(Planner.byDate(Scanner.scan(root), root: root), title: "date")
        XCTAssertTrue(exists("2025/03-March/a.txt")); XCTAssertTrue(exists("2026/11-November/b.txt"))
        Executor.undo(op)
        XCTAssertEqual(names(), ["a.txt", "b.txt"])
    }

    func testOldFilesSelectionBoundaries() throws {
        try make("new.txt", daysOld: 1); try make("m.txt", daysOld: 45); try make("o.txt", daysOld: 100); try make("vo.txt", daysOld: 400)
        let items = Scanner.scan(root)
        XCTAssertEqual(Planner.oldFiles(items, days: 30).map { $0.name }.sorted(), ["m.txt", "o.txt", "vo.txt"])
        XCTAssertEqual(Planner.oldFiles(items, days: 60).map { $0.name }.sorted(), ["o.txt", "vo.txt"])
        XCTAssertEqual(Planner.oldFiles(items, days: 90).map { $0.name }.sorted(), ["o.txt", "vo.txt"])
        XCTAssertEqual(Planner.oldFiles(items, days: 365).map { $0.name }, ["vo.txt"])
        XCTAssertEqual(Planner.oldFiles(items, days: 1000).count, 0)
    }

    func testMoveOldAndUndo() throws {
        try make("new.txt", daysOld: 2); try make("o.txt", daysOld: 100)
        let old = Planner.oldFiles(Scanner.scan(root), days: 30)
        let op = Executor.apply(Planner.moveOld(old, root: root), title: "old")
        XCTAssertTrue(exists("Old Files/o.txt")); XCTAssertTrue(exists("new.txt"))
        XCTAssertEqual(Executor.undo(op), 1)
        XCTAssertTrue(exists("o.txt")); XCTAssertFalse(exists("Old Files"))
    }

    func testOldFilesKeepModifiedDateAfterMove() throws {
        try make("o.txt", daysOld: 100)
        Executor.apply(Planner.moveOld(Planner.oldFiles(Scanner.scan(root), days: 30), root: root), title: "old")
        let moved = Scanner.scan(root.appendingPathComponent("Old Files"))
        XCTAssertEqual(moved.count, 1)
        XCTAssertLessThan(moved[0].modified, Date().addingTimeInterval(-99 * 86_400))
    }
}
