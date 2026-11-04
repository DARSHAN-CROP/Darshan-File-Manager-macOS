import Foundation

/// A regular file found by the scanner.
public struct FileItem: Equatable, Hashable, Identifiable {
    public let url: URL
    public let size: Int64
    public let modified: Date
    public var id: String { url.path }
    public var name: String { url.lastPathComponent }
    /// Lower-case extension without the dot ("" when none). Handles ".tar.gz" as "tar.gz".
    public var ext: String { FileItem.extensionOf(name) }

    public init(url: URL, size: Int64, modified: Date) {
        self.url = url; self.size = size; self.modified = modified
    }

    public static func extensionOf(_ name: String) -> String {
        let lower = name.lowercased()
        for double in ["tar.gz", "tar.bz2", "tar.xz", "tar.zst"] where lower.hasSuffix("." + double) { return double }
        guard let dot = lower.lastIndex(of: "."), dot != lower.startIndex else { return "" }
        let e = String(lower[lower.index(after: dot)...])
        return e
    }
}

/// One planned move (source -> destination). Destination names are made unique when applied.
public struct PlannedMove: Equatable {
    public let from: URL
    public let to: URL
    public init(from: URL, to: URL) { self.from = from; self.to = to }
}

/// A move that really happened (journal entry).
public struct MoveRecord: Codable, Equatable {
    public let from: String
    public let to: String
}

/// One undo-able operation: everything that moved plus folders that were created.
public struct FileOperation: Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let date: Date
    public let moves: [MoveRecord]
    public let createdDirs: [String]
    public var count: Int { moves.count }
}

public enum Category: String, CaseIterable, Codable {
    case images = "Images", videos = "Videos", audio = "Audio", documents = "Documents"
    case archives = "Archives", code = "Code", others = "Others"

    public var folderName: String { rawValue }

    private static let map: [String: Category] = {
        var m: [String: Category] = [:]
        func add(_ c: Category, _ exts: String) { for e in exts.split(separator: " ") { m[String(e)] = c } }
        add(.images, "jpg jpeg png gif bmp webp heic heif tif tiff svg ico raw cr2 nef dng psd ai eps avif")
        add(.videos, "mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp ts vob")
        add(.audio, "mp3 wav aac flac ogg m4a wma opus aiff amr mid midi")
        add(.documents, "pdf doc docx xls xlsx ppt pptx txt rtf odt ods odp csv md epub mobi pages numbers key tex")
        add(.archives, "zip rar 7z tar gz tar.gz tar.bz2 tar.xz tar.zst bz2 xz iso dmg pkg cab")
        add(.code, "swift c h cpp hpp cs java kt py js jsx tsx html htm css json xml yml yaml sh bat ps1 php rb go rs sql ini toml")
        return m
    }()

    public static func of(ext: String) -> Category { map[ext.lowercased()] ?? .others }
    public static func of(_ item: FileItem) -> Category { of(ext: item.ext) }
}

public enum FileFilters {
    /// Temporary / system names that must never be moved.
    public static func shouldSkip(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasPrefix(".") { return true }
        if ["thumbs.db", "desktop.ini", "icon\r"].contains(lower) { return true }
        for e in ["crdownload", "part", "tmp", "download", "partial"] where lower.hasSuffix("." + e) { return true }
        return false
    }
}

public func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var v = Double(max(bytes, 0)); var i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    if i == 0 { return "\(Int(v)) B" }
    return String(format: "%.1f", v) + " " + units[i]
}
