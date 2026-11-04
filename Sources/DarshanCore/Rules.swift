import Foundation

/// A user-defined rule: "extension(s) are X" or "name contains X"  ->  folder Y.
public struct Rule: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable, CaseIterable { case extensions, nameContains }

    public var id: UUID
    public var kind: Kind
    /// For `.extensions`: comma / space separated list ("jpg, png"). For `.nameContains`: the text.
    public var value: String
    /// Destination folder (relative to the sorted folder). Nested like "Work/Invoices" is allowed.
    public var folder: String

    public init(id: UUID = UUID(), kind: Kind, value: String, folder: String) {
        self.id = id; self.kind = kind; self.value = value; self.folder = folder
    }

    public var extensionList: [String] {
        value.split(whereSeparator: { ", ;".contains($0) })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() }
            .filter { !$0.isEmpty }
    }

    public var isValid: Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty && !Rule.sanitizedFolder(folder).isEmpty
    }

    public func matches(name: String, ext: String) -> Bool {
        switch kind {
        case .extensions: return extensionList.contains(ext.lowercased())
        case .nameContains:
            let needle = value.trimmingCharacters(in: .whitespaces)
            return !needle.isEmpty && name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Keeps only safe relative path components (no "..", no absolute paths, no illegal characters).
    public static func sanitizedFolder(_ raw: String) -> String {
        let bad = CharacterSet(charactersIn: ":*?\"<>|\\")
        let parts = raw.split(whereSeparator: { "/\\".contains($0) }).map { part -> String in
            String(part).components(separatedBy: bad).joined().trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty && $0 != "." && $0 != ".." }
        return parts.joined(separator: "/")
    }
}

public enum RuleEngine {
    /// First matching rule wins (order in the list = priority).
    public static func firstMatch(_ item: FileItem, rules: [Rule]) -> Rule? {
        rules.first { $0.isValid && $0.matches(name: item.name, ext: item.ext) }
    }
}
