import Foundation

public struct AutoSummary: Equatable {
    public var sorted = 0
    public var duplicatesMoved = 0
    public var oldMoved = 0
    public var operations: [FileOperation] = []
    public init() {}

    public var total: Int { sorted + duplicatesMoved + oldMoved }

    /// "12 sorted, 3 duplicates moved, 5 old files moved" (parts with 0 are left out).
    public func text(_ lang: Language) -> String {
        var parts: [String] = []
        if sorted > 0 { parts.append(L.t("summary_sorted", lang, [String(sorted)])) }
        if duplicatesMoved > 0 { parts.append(L.t("summary_dups", lang, [String(duplicatesMoved)])) }
        if oldMoved > 0 { parts.append(L.t("summary_old", lang, [String(oldMoved)])) }
        return parts.isEmpty ? L.t("summary_nothing", lang) : parts.joined(separator: ", ")
    }
}

public enum AutoRunner {
    /// Refuses the file-system root and top-level system folders.
    public static func isSafeFolder(_ url: URL) -> Bool {
        let comps = url.standardizedFileURL.pathComponents.filter { $0 != "/" }
        if comps.count < 2 { return false }
        let bad: Set<String> = ["System", "Library", "bin", "sbin", "usr", "etc", "var", "private", "Applications"]
        return !(comps.count == 2 && bad.contains(comps[0]))
    }

    /// Runs the ticked actions in a sensible order:
    /// 1. my rules, 2. duplicates (moved to "Duplicates"), 3. old files, 4. type OR extension sort, 5. date sort (leftovers).
    @discardableResult
    public static func run(folder: URL, settings: AppSettings, journal: Journal? = nil, now: Date = Date()) -> AutoSummary {
        var summary = AutoSummary()
        guard isSafeFolder(folder) else { return summary }
        let a = settings.auto
        func commit(_ plan: [PlannedMove], _ title: String) -> Int {
            guard !plan.isEmpty else { return 0 }
            let op = Executor.apply(plan, title: title)
            journal?.push(op)
            if !op.moves.isEmpty { summary.operations.append(op) }
            return op.moves.count
        }

        if a.customRules && !settings.rules.isEmpty {
            let items = Scanner.scan(folder)
            summary.sorted += commit(Planner.rules(items, root: folder, rules: settings.rules), "Auto: rules")
        }
        if a.duplicates {
            let groups = DuplicateFinder.find(in: folder, recursive: true, skipOwnFolders: true)
            let files = DuplicateFinder.filesToMove(groups: groups, selected: DuplicateFinder.defaultSelection(groups))
            summary.duplicatesMoved += commit(Planner.moveDuplicates(files, root: folder), "Auto: duplicates")
        }
        if a.oldFiles {
            let old = Planner.oldFiles(Scanner.scan(folder), days: a.oldDays, now: now)
            summary.oldMoved += commit(Planner.moveOld(old, root: folder), "Auto: old files")
        }
        if a.sortByType {
            summary.sorted += commit(Planner.byType(Scanner.scan(folder), root: folder, rules: a.customRules ? settings.rules : []), "Auto: sort by type")
        } else if a.sortByExtension {
            summary.sorted += commit(Planner.byExtension(Scanner.scan(folder), root: folder, rules: a.customRules ? settings.rules : []), "Auto: sort by extension")
        }
        if a.sortByDate {
            summary.sorted += commit(Planner.byDate(Scanner.scan(folder), root: folder), "Auto: sort by date")
        }
        return summary
    }
}
