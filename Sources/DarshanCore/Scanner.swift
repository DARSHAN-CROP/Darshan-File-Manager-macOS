import Foundation

public enum Scanner {
    /// Folder names created by this app; skipped when scanning recursively so we never re-process our own output.
    public static let ownFolders: Set<String> = ["Duplicates", "Old Files"]

    /// Lists regular files in `folder`. Hidden, temporary and system files are skipped.
    public static func scan(_ folder: URL, recursive: Bool = false, skipOwnFolders: Bool = false) -> [FileItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey]
        var result: [FileItem] = []

        func item(_ url: URL) -> FileItem? {
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true, v.isSymbolicLink != true else { return nil }
            if FileFilters.shouldSkip(url.lastPathComponent) { return nil }
            return FileItem(url: url, size: Int64(v.fileSize ?? 0), modified: v.contentModificationDate ?? Date())
        }

        if recursive {
            guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
            for case let url as URL in en {
                if skipOwnFolders, (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                   ownFolders.contains(url.lastPathComponent) {
                    en.skipDescendants(); continue
                }
                if let it = item(url) { result.append(it) }
            }
        } else if let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for url in urls { if let it = item(url) { result.append(it) } }
        }
        return result.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
    }
}
