import Foundation

public struct CategoryUsage: Equatable, Identifiable {
    public let category: Category
    public let count: Int
    public let bytes: Int64
    public var id: String { category.rawValue }
}

public enum StorageStats {
    /// Per-category totals, biggest first. Categories with no files are omitted.
    public static func usage(_ items: [FileItem]) -> [CategoryUsage] {
        var count: [Category: Int] = [:], bytes: [Category: Int64] = [:]
        for it in items { let c = Category.of(it); count[c, default: 0] += 1; bytes[c, default: 0] += it.size }
        return Category.allCases.compactMap { c in
            guard let n = count[c] else { return nil }
            return CategoryUsage(category: c, count: n, bytes: bytes[c] ?? 0)
        }.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.category.rawValue < $1.category.rawValue }
    }

    public static func usage(in folder: URL, recursive: Bool = true) -> [CategoryUsage] {
        usage(Scanner.scan(folder, recursive: recursive))
    }

    public static func total(_ u: [CategoryUsage]) -> (count: Int, bytes: Int64) {
        (u.reduce(0) { $0 + $1.count }, u.reduce(0) { $0 + $1.bytes })
    }
}
