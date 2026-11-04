import Foundation

public enum Executor {
    /// "name.ext" -> "name (1).ext", "name (2).ext", ... until a free path is found.
    public static func uniqueURL(_ url: URL, fm: FileManager = .default) -> URL {
        if !fm.fileExists(atPath: url.path) { return url }
        let dir = url.deletingLastPathComponent()
        let name = url.lastPathComponent
        let ext = FileItem.extensionOf(name)
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        var n = 1
        while true {
            let candidate = dir.appendingPathComponent(ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    /// Performs the planned moves, creating folders as needed. Never overwrites anything.
    /// Returns an FileOperation describing what happened (empty `moves` when nothing moved).
    public static func apply(_ plan: [PlannedMove], title: String, fm: FileManager = .default) -> FileOperation {
        var records: [MoveRecord] = []
        var created: [String] = []
        for m in plan {
            guard fm.fileExists(atPath: m.from.path) else { continue }
            // create missing folders, remember which ones are new
            var missing: [URL] = []
            var dir = m.to.deletingLastPathComponent()
            while !fm.fileExists(atPath: dir.path) && dir.path != "/" {
                missing.append(dir); dir = dir.deletingLastPathComponent()
            }
            do {
                for d in missing.reversed() {
                    try fm.createDirectory(at: d, withIntermediateDirectories: false)
                    created.append(d.path)
                }
                let dest = uniqueURL(m.to, fm: fm)
                if dest.path == m.from.path { continue }
                try fm.moveItem(at: m.from, to: dest)
                records.append(MoveRecord(from: m.from.path, to: dest.path))
            } catch { continue }
        }
        return FileOperation(id: UUID(), title: title, date: Date(), moves: records, createdDirs: created)
    }

    /// Reverses an operation (last move first). Returns how many files were put back.
    @discardableResult
    public static func undo(_ op: FileOperation, fm: FileManager = .default) -> Int {
        var restored = 0
        for r in op.moves.reversed() {
            guard fm.fileExists(atPath: r.to) else { continue }
            let target = uniqueURL(URL(fileURLWithPath: r.from), fm: fm)
            do {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: URL(fileURLWithPath: r.to), to: target)
                restored += 1
            } catch { continue }
        }
        // remove folders we created, deepest first, only when empty
        for d in op.createdDirs.sorted(by: { $0.count > $1.count }) {
            if let items = try? fm.contentsOfDirectory(atPath: d), items.allSatisfy({ $0 == ".DS_Store" }) {
                try? fm.removeItem(atPath: d)
            }
        }
        return restored
    }
}

/// Persistent undo journal (JSON file). Newest operation last.
public final class Journal {
    public private(set) var operations: [FileOperation] = []
    private let fileURL: URL?
    private let limit: Int

    public init(fileURL: URL? = nil, limit: Int = 50) {
        self.fileURL = fileURL; self.limit = limit
        if let u = fileURL, let data = try? Data(contentsOf: u),
           let ops = try? JSONDecoder.iso.decode([FileOperation].self, from: data) { operations = ops }
    }

    public func push(_ op: FileOperation) {
        guard !op.moves.isEmpty else { return }
        operations.append(op)
        if operations.count > limit { operations.removeFirst(operations.count - limit) }
        save()
    }

    public var last: FileOperation? { operations.last }

    /// Undoes the newest operation. Returns it (nil when there was nothing to undo) and the number of files restored.
    @discardableResult
    public func undoLast() -> (FileOperation, Int)? {
        guard let op = operations.popLast() else { return nil }
        let n = Executor.undo(op)
        save()
        return (op, n)
    }

    private func save() {
        guard let u = fileURL else { return }
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder.iso.encode(operations) { try? data.write(to: u, options: .atomic) }
    }
}

extension JSONEncoder { static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e } }
extension JSONDecoder { static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d } }
