import XCTest
@testable import DarshanCore

final class RulesTests: TempTestCase {
    func testExtensionRuleMatchingAndParsing() {
        let r = Rule(kind: .extensions, value: "JPG, .png  heic", folder: "Pics")
        XCTAssertEqual(r.extensionList, ["jpg", "png", "heic"])
        XCTAssertTrue(r.matches(name: "x.PNG", ext: "png"))
        XCTAssertFalse(r.matches(name: "x.pdf", ext: "pdf"))
    }

    func testNameContainsCaseInsensitive() {
        let r = Rule(kind: .nameContains, value: "Invoice", folder: "Bills")
        XCTAssertTrue(r.matches(name: "my-INVOICE-3.pdf", ext: "pdf"))
        XCTAssertFalse(r.matches(name: "photo.jpg", ext: "jpg"))
        XCTAssertFalse(Rule(kind: .nameContains, value: "  ", folder: "x").matches(name: "a", ext: ""))
    }

    func testFirstMatchWinsPrecedence() throws {
        let rules = [Rule(kind: .nameContains, value: "invoice", folder: "Bills"),
                     Rule(kind: .extensions, value: "pdf", folder: "PDFs")]
        let item = FileItem(url: root.appendingPathComponent("invoice.pdf"), size: 1, modified: Date())
        XCTAssertEqual(RuleEngine.firstMatch(item, rules: rules)?.folder, "Bills")
        let item2 = FileItem(url: root.appendingPathComponent("book.pdf"), size: 1, modified: Date())
        XCTAssertEqual(RuleEngine.firstMatch(item2, rules: rules)?.folder, "PDFs")
    }

    func testRulesAppliedBeforeBuiltInTypes() throws {
        try make("holiday.jpg"); try make("invoice.pdf"); try make("song.mp3")
        let rules = [Rule(kind: .extensions, value: "jpg", folder: "Trips"), Rule(kind: .nameContains, value: "invoice", folder: "Work/Bills")]
        Executor.apply(Planner.byType(Scanner.scan(root), root: root, rules: rules), title: "t")
        XCTAssertTrue(exists("Trips/holiday.jpg"))
        XCTAssertTrue(exists("Work/Bills/invoice.pdf"))
        XCTAssertTrue(exists("Audio/song.mp3"))
        XCTAssertFalse(exists("Images"))
    }

    func testRulesOnlyPlanLeavesOthers() throws {
        try make("a.jpg"); try make("b.pdf")
        let plan = Planner.rules(Scanner.scan(root), root: root, rules: [Rule(kind: .extensions, value: "pdf", folder: "Docs")])
        XCTAssertEqual(plan.count, 1)
        Executor.apply(plan, title: "t")
        XCTAssertTrue(exists("a.jpg")); XCTAssertTrue(exists("Docs/b.pdf"))
    }

    func testFolderSanitizingBlocksTraversal() {
        XCTAssertEqual(Rule.sanitizedFolder("../../etc"), "etc")
        XCTAssertEqual(Rule.sanitizedFolder("/abs/path"), "abs/path")
        XCTAssertEqual(Rule.sanitizedFolder("a:b*c/d?"), "abc/d")
        XCTAssertEqual(Rule.sanitizedFolder("..") , "")
        XCTAssertFalse(Rule(kind: .extensions, value: "jpg", folder: "..").isValid)
        XCTAssertFalse(Rule(kind: .extensions, value: "", folder: "x").isValid)
    }

    func testTraversalRuleStaysInsideRoot() throws {
        try make("a.jpg")
        let plan = Planner.rules(Scanner.scan(root), root: root, rules: [Rule(kind: .extensions, value: "jpg", folder: "../../outside")])
        XCTAssertTrue(plan[0].to.path.hasPrefix(root.path))
    }

    func testRulesRoundTripThroughSettings() {
        let suite = UserDefaults(suiteName: "test-rules-" + UUID().uuidString)!
        let store = SettingsStore(defaults: suite)
        var s = AppSettings()
        s.rules = [Rule(kind: .extensions, value: "png", folder: "P"), Rule(kind: .nameContains, value: "x", folder: "Q")]
        store.save(s)
        XCTAssertEqual(store.load().rules, s.rules)
    }
}
