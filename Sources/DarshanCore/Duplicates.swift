import Foundation

public struct DuplicateGroup: Equatable, Identifiable {
    public let size: Int64
    public let hash: String
    /// files[0] is the one we keep (oldest modified date, then shortest path).
    public let files: [FileItem]
    public var id: String { hash + "-" + String(size) }
    public var original: FileItem { files[0] }
    public var copies: [FileItem] { Array(files.dropFirst()) }
    public var wastedBytes: Int64 { size * Int64(files.count - 1) }
}

public enum DuplicateFinder {
    /// Groups by size first (cheap), then hashes only files that share a size.
    public static func find(in folder: URL, recursive: Bool = true, skipOwnFolders: Bool = true) -> [DuplicateGroup] {
        group(Scanner.scan(folder, recursive: recursive, skipOwnFolders: skipOwnFolders))
    }

    public static func group(_ items: [FileItem]) -> [DuplicateGroup] {
        var bySize: [Int64: [FileItem]] = [:]
        for it in items where it.size > 0 { bySize[it.size, default: []].append(it) }
        var groups: [DuplicateGroup] = []
        for (size, list) in bySize where list.count > 1 {
            var byHash: [String: [FileItem]] = [:]
            for it in list {
                guard let h = Hashing.sha256Hex(ofFile: it.url) else { continue }
                byHash[h, default: []].append(it)
            }
            for (h, files) in byHash where files.count > 1 {
                let sorted = files.sorted {
                    if $0.modified != $1.modified { return $0.modified < $1.modified }
                    if $0.url.path.count != $1.url.path.count { return $0.url.path.count < $1.url.path.count }
                    return $0.url.path < $1.url.path
                }
                groups.append(DuplicateGroup(size: size, hash: h, files: sorted))
            }
        }
        return groups.sorted { $0.wastedBytes != $1.wastedBytes ? $0.wastedBytes > $1.wastedBytes : $0.hash < $1.hash }
    }

    public static func totalWasted(_ groups: [DuplicateGroup]) -> Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }

    /// Default selection = every copy, never the original.
    public static func defaultSelection(_ groups: [DuplicateGroup]) -> Set<String> {
        Set(groups.flatMap { $0.copies.map { $0.id } })
    }

    /// Files to move to "Duplicates". Safety rule: at least one file of each group always stays in place.
    public static func filesToMove(groups: [DuplicateGroup], selected: Set<String>) -> [FileItem] {
        var out: [FileItem] = []
        for g in groups {
            let chosen = g.files.filter { selected.contains($0.id) }
            if chosen.count >= g.files.count { out.append(contentsOf: chosen.dropFirst()) }  // keep the original
            else { out.append(contentsOf: chosen) }
        }
        return out
    }
}
