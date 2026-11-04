import Foundation
import XCTest
@testable import DarshanCore

class TempTestCase: XCTestCase {
    var root: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("darshan-tests-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? fm.removeItem(at: root) }

    @discardableResult
    func make(_ path: String, _ content: String = "x", daysOld: Double = 0) throws -> URL {
        let url = root.appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: url)
        if daysOld > 0 {
            try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-daysOld * 86_400)], ofItemAtPath: url.path)
        }
        return url
    }
    func exists(_ path: String) -> Bool { fm.fileExists(atPath: root.appendingPathComponent(path).path) }
    func names(_ path: String = "") -> [String] {
        let u = path.isEmpty ? root! : root.appendingPathComponent(path)
        return ((try? fm.contentsOfDirectory(atPath: u.path)) ?? []).sorted()
    }
}
