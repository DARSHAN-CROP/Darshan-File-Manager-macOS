import Foundation

public struct RenameOptions: Equatable, Codable {
    /// Only files whose name contains this text (empty = all).
    public var nameContains = ""
    /// Only these extensions, comma separated (empty = all).
    public var extensions = ""
    public var prefix = ""
    public var suffix = ""
    public var find = ""
    public var replace = ""
    /// If not empty the whole base name is replaced by this ("Photo" -> Photo_001 when numbering is on).
    public var baseName = ""
    public var numbering = false
    public var startNumber = 1
    public var digits = 3

    public init() {}
}

public struct RenameItem: Equatable, Identifiable {
    public let from: URL
    public let newName: String
    public var id: String { from.path }
    public var oldName: String { from.lastPathComponent }
}

public enum Renamer {
    public static func matches(_ item: FileItem, _ o: RenameOptions) -> Bool {
        let n = o.nameContains.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty && item.name.range(of: n, options: [.caseInsensitive]) == nil { return false }
        let exts = o.extensions.split(whereSeparator: { ", ;".contains($0) })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() }.filter { !$0.isEmpty }
        if !exts.isEmpty && !exts.contains(item.ext) { return false }
        return true
    }

    /// Preview: never touches the disk. Items whose name would not change are left out.
    public static func plan(_ items: [FileItem], _ o: RenameOptions) -> [RenameItem] {
        let chosen = items.filter { matches($0, o) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var out: [RenameItem] = []
        var number = o.startNumber
        for it in chosen {
            let ext = it.ext
            var base = ext.isEmpty ? it.name : String(it.name.dropLast(ext.count + 1))
            if !o.baseName.isEmpty { base = o.baseName }
            else if !o.find.isEmpty { base = base.replacingOccurrences(of: o.find, with: o.replace) }
            if o.numbering { base += "_" + String(format: "%0\(max(o.digits, 1))d", number); number += 1 }
            let name = sanitize(o.prefix + base + o.suffix)
            let full = ext.isEmpty ? name : name + "." + originalExt(it)
            if full != it.name && !name.isEmpty { out.append(RenameItem(from: it.url, newName: full)) }
        }
        return out
    }

    /// Keeps the original extension spelling (e.g. "JPG").
    private static func originalExt(_ it: FileItem) -> String {
        let e = it.ext
        return String(it.name.suffix(e.count))
    }

    private static func sanitize(_ s: String) -> String {
        s.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined()
    }

    public static func moves(_ plan: [RenameItem]) -> [PlannedMove] {
        plan.map { PlannedMove(from: $0.from, to: $0.from.deletingLastPathComponent().appendingPathComponent($0.newName)) }
    }
}
