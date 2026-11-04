import Foundation

public enum DateFolders {
    public static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                                    "August", "September", "October", "November", "December"]

    /// "2026/11-November" for the modified date.
    public static func name(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        let y = c.year ?? 1970, m = min(max(c.month ?? 1, 1), 12)
        return String(format: "%04d/%02d-%@", y, m, monthNames[m - 1])
    }
}

public enum Planner {
    private static func dest(_ root: URL, _ folder: String, _ name: String) -> URL {
        var u = root
        for part in folder.split(separator: "/") { u = u.appendingPathComponent(String(part), isDirectory: true) }
        return u.appendingPathComponent(name)
    }

    /// Only files matched by the user's rules (first match wins).
    public static func rules(_ items: [FileItem], root: URL, rules: [Rule]) -> [PlannedMove] {
        items.compactMap { it in
            guard let r = RuleEngine.firstMatch(it, rules: rules) else { return nil }
            let f = Rule.sanitizedFolder(r.folder)
            return PlannedMove(from: it.url, to: dest(root, f, it.name))
        }
    }

    /// Custom rules first, then the built-in type map (Images, Videos, ...).
    public static func byType(_ items: [FileItem], root: URL, rules: [Rule] = []) -> [PlannedMove] {
        items.map { it in
            if let r = RuleEngine.firstMatch(it, rules: rules) {
                return PlannedMove(from: it.url, to: dest(root, Rule.sanitizedFolder(r.folder), it.name))
            }
            return PlannedMove(from: it.url, to: dest(root, Category.of(it).folderName, it.name))
        }
    }

    /// One folder per extension (JPG, PDF, NO_EXTENSION). Custom rules first.
    public static func byExtension(_ items: [FileItem], root: URL, rules: [Rule] = []) -> [PlannedMove] {
        items.map { it in
            if let r = RuleEngine.firstMatch(it, rules: rules) {
                return PlannedMove(from: it.url, to: dest(root, Rule.sanitizedFolder(r.folder), it.name))
            }
            let e = it.ext
            let folder = e.isEmpty ? "NO_EXTENSION" : e.uppercased().replacingOccurrences(of: ".", with: "_")
            return PlannedMove(from: it.url, to: dest(root, folder, it.name))
        }
    }

    /// Year/Month folders by modified date.
    public static func byDate(_ items: [FileItem], root: URL, calendar: Calendar = Calendar(identifier: .gregorian)) -> [PlannedMove] {
        items.map { PlannedMove(from: $0.url, to: dest(root, DateFolders.name(for: $0.modified, calendar: calendar), $0.name)) }
    }

    // MARK: Old files

    public static let oldFolder = "Old Files"
    public static let duplicatesFolder = "Duplicates"

    /// Files not modified for more than `days` days.
    public static func oldFiles(_ items: [FileItem], days: Int, now: Date = Date()) -> [FileItem] {
        let cutoff = now.addingTimeInterval(-Double(max(days, 0)) * 86_400)
        return items.filter { $0.modified < cutoff }
    }

    public static func moveOld(_ old: [FileItem], root: URL) -> [PlannedMove] {
        old.map { PlannedMove(from: $0.url, to: dest(root, oldFolder, $0.name)) }
    }

    // MARK: Duplicates

    public static func moveDuplicates(_ files: [FileItem], root: URL) -> [PlannedMove] {
        files.map { PlannedMove(from: $0.url, to: dest(root, duplicatesFolder, $0.name)) }
    }
}
