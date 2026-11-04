#if canImport(SwiftUI)
import SwiftUI
import Foundation
import DarshanCore
import UserNotifications

@MainActor
public final class AppModel: ObservableObject {
    // MARK: state
    @Published public var settings: AppSettings { didSet { if settings != oldValue { store.save(settings); settingsChanged(old: oldValue) } } }
    @Published public var folder: URL?
    @Published public var status = ""
    @Published public var log: [String] = []
    @Published public var canUndo = false
    @Published public var busy = false

    // results shown by the tabs
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var duplicateSelection: Set<String> = []
    @Published public var duplicatesScanned = false
    @Published public var oldPreview: [FileItem] = []
    @Published public var oldScanned = false
    @Published public var renameOptions = RenameOptions()
    @Published public var renamePreview: [RenameItem] = []
    @Published public var usage: [CategoryUsage] = []
    @Published public var usageScanned = false

    public let store: SettingsStore
    public let journal: Journal
    private var autoTimer: Timer?
    private var scopedURL: URL?

    public init(store: SettingsStore = SettingsStore(), journalURL: URL? = AppModel.defaultJournalURL()) {
        self.store = store
        self.settings = store.load()
        self.journal = Journal(fileURL: journalURL)
        self.canUndo = journal.last != nil
        restoreFolder()
        scheduleAuto()
    }

    nonisolated public static func defaultJournalURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("DarshanFileManager", isDirectory: true).appendingPathComponent("journal.json")
    }

    // MARK: language
    public var lang: Language { settings.language }
    public func t(_ key: String, _ args: [String] = []) -> String { L.t(key, lang, args) }

    // MARK: folder
    private let folderKey = "darshan.lastFolder.v1"

    public func setFolder(_ url: URL) {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        folder = url
        resetResults()
        #if os(iOS)
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: folderKey)
        }
        #else
        UserDefaults.standard.set(url.path, forKey: folderKey)
        #endif
        status = ""
    }

    private func restoreFolder() {
        #if os(iOS)
        if let data = UserDefaults.standard.data(forKey: folderKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                if url.startAccessingSecurityScopedResource() { scopedURL = url }
                folder = url
            }
        }
        #else
        if let path = UserDefaults.standard.string(forKey: folderKey), FileManager.default.fileExists(atPath: path) {
            folder = URL(fileURLWithPath: path)
        }
        #endif
    }

    public func resetResults() {
        duplicateGroups = []; duplicateSelection = []; duplicatesScanned = false
        oldPreview = []; oldScanned = false
        renamePreview = []
        usage = []; usageScanned = false
    }

    // MARK: helpers
    private func work<T>(_ f: @escaping @Sendable () -> T) async -> T {
        busy = true
        let r = await Task.detached(priority: .userInitiated) { f() }.value
        busy = false
        return r
    }

    private func addLog(_ s: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        log.insert("\(f.string(from: Date()))  \(s)", at: 0)
        if log.count > 60 { log.removeLast(log.count - 60) }
        status = s
    }

    private func finish(_ op: FileOperation, title: String, countKey: String) {
        journal.push(op)
        canUndo = journal.last != nil
        addLog(op.count == 0 ? t("nothing_to_move") : title + ": " + t(countKey, [String(op.count)]))
    }

    public var hasFolder: Bool { folder != nil }

    /// Path shown to the user, relative to the chosen folder.
    public func relativePath(_ url: URL) -> String {
        guard let f = folder?.standardizedFileURL.path else { return url.path }
        let p = url.standardizedFileURL.path
        if p.hasPrefix(f + "/") { return String(p.dropFirst(f.count + 1)) }
        return url.lastPathComponent
    }

    // MARK: sorting
    public enum SortKind { case type, ext, date, rules }

    public func sort(_ kind: SortKind) async {
        guard let root = folder, !busy else { addLog(t("pick_first")); return }
        let rules = settings.rules
        let plan: [PlannedMove] = await work {
            let items = Scanner.scan(root)
            switch kind {
            case .type: return Planner.byType(items, root: root, rules: rules)
            case .ext: return Planner.byExtension(items, root: root, rules: rules)
            case .date: return Planner.byDate(items, root: root)
            case .rules: return Planner.rules(items, root: root, rules: rules)
            }
        }
        let title: String
        switch kind {
        case .type: title = t("sort_by_type")
        case .ext: title = t("sort_by_ext")
        case .date: title = t("sort_by_date")
        case .rules: title = t("apply_rules")
        }
        let op = await work { Executor.apply(plan, title: title) }
        finish(op, title: title, countKey: "moved_n")
        resetResults()
    }

    public func undo() async {
        guard !busy else { return }
        guard journal.last != nil else { addLog(t("nothing_to_undo")); return }
        let j = journal
        let r = await work { j.undoLast() }
        canUndo = journal.last != nil
        addLog(t("undone", [String(r?.1 ?? 0)]))
        resetResults()
    }

    // MARK: duplicates
    public func scanDuplicates() async {
        guard let root = folder, !busy else { addLog(t("pick_first")); return }
        let sub = settings.includeSubfolders
        let groups = await work { DuplicateFinder.find(in: root, recursive: sub) }
        duplicateGroups = groups
        duplicateSelection = DuplicateFinder.defaultSelection(groups)
        duplicatesScanned = true
        status = groups.isEmpty ? t("dup_none") : t("dup_groups", [String(groups.count)])
    }

    public func moveDuplicates() async {
        guard let root = folder, !busy else { return }
        let files = DuplicateFinder.filesToMove(groups: duplicateGroups, selected: duplicateSelection)
        let op = await work { Executor.apply(Planner.moveDuplicates(files, root: root), title: "Duplicates") }
        finish(op, title: t("tab_duplicates"), countKey: "dup_moved")
        duplicateGroups = []; duplicateSelection = []
        duplicatesScanned = false
    }

    public func toggleDuplicate(_ f: FileItem) {
        if duplicateSelection.contains(f.id) { duplicateSelection.remove(f.id) } else { duplicateSelection.insert(f.id) }
    }

    public var selectedDuplicateBytes: Int64 {
        DuplicateFinder.filesToMove(groups: duplicateGroups, selected: duplicateSelection).reduce(0) { $0 + $1.size }
    }

    // MARK: old files
    public func previewOld() async {
        guard let root = folder, !busy else { addLog(t("pick_first")); return }
        let days = settings.oldDays
        let sub = settings.includeSubfolders
        let old = await work { Planner.oldFiles(Scanner.scan(root, recursive: sub, skipOwnFolders: true), days: days) }
        oldPreview = old
        oldScanned = true
    }

    public func moveOld() async {
        guard let root = folder, !busy else { return }
        let old = oldPreview
        let op = await work { Executor.apply(Planner.moveOld(old, root: root), title: "Old Files") }
        finish(op, title: t("tab_old"), countKey: "old_moved")
        oldPreview = []; oldScanned = false
    }

    // MARK: rename
    public func previewRename() async {
        guard let root = folder, !busy else { addLog(t("pick_first")); return }
        let o = renameOptions
        let sub = settings.includeSubfolders
        let plan = await work { Renamer.plan(Scanner.scan(root, recursive: sub, skipOwnFolders: true), o) }
        renamePreview = plan
        status = plan.isEmpty ? t("rename_none") : t("files_n", [String(plan.count)])
    }

    public func applyRename() async {
        guard !renamePreview.isEmpty, !busy else { return }
        let plan = renamePreview
        let op = await work { Executor.apply(Renamer.moves(plan), title: "Rename") }
        finish(op, title: t("tab_rename"), countKey: "renamed_n")
        renamePreview = []
    }

    // MARK: storage
    public func calculateStorage() async {
        guard let root = folder, !busy else { addLog(t("pick_first")); return }
        let sub = settings.includeSubfolders
        usage = await work { StorageStats.usage(in: root, recursive: sub) }
        usageScanned = true
    }

    // MARK: rules
    public func saveRule(_ rule: Rule) {
        if let i = settings.rules.firstIndex(where: { $0.id == rule.id }) { settings.rules[i] = rule }
        else { settings.rules.append(rule) }
    }
    public func deleteRule(_ rule: Rule) { settings.rules.removeAll { $0.id == rule.id } }

    // MARK: auto mode
    public func runAuto() async {
        guard let root = folder, !busy else { return }
        let s = settings
        let j = journal
        let summary = await work { AutoRunner.run(folder: root, settings: s, journal: j) }
        canUndo = journal.last != nil
        let text = summary.text(lang)
        addLog(t("auto_title") + ": " + text)
        if settings.auto.notify && summary.total > 0 { Notifier.post(title: t("app_title"), body: text) }
        resetResults()
    }

    private func settingsChanged(old: AppSettings) {
        if old.auto != settings.auto { scheduleAuto() }
        if !old.auto.notify && settings.auto.notify { Notifier.requestPermission() }
        if !old.auto.enabled && settings.auto.enabled && settings.auto.notify { Notifier.requestPermission() }
    }

    public func scheduleAuto() {
        autoTimer?.invalidate(); autoTimer = nil
        guard settings.auto.enabled else { return }
        let minutes = max(settings.auto.intervalMinutes, 1)
        autoTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runAuto() }
        }
    }

    /// iOS cannot run in the background; run once when the app comes to the foreground.
    public func appBecameActive() {
        if settings.auto.enabled { Task { await runAuto() } }
    }
}

enum Notifier {
    private static var available: Bool {
        #if os(macOS)
        return Bundle.main.bundleURL.pathExtension == "app"
        #else
        return true
        #endif
    }
    static func requestPermission() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    static func post(title: String, body: String) {
        guard available else { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
#endif
