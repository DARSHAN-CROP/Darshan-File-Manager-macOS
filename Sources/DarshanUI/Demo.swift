#if canImport(SwiftUI)
import SwiftUI
import Foundation
import DarshanCore

/// Demo mode (used for the screenshots built in CI): `-demo YES -tab 2 -theme dark -accent gold -lang gu`.
/// It works on a throw-away sample folder and a separate settings store, so real data is never touched.
public enum DemoMode {
    public static var requested: Bool { UserDefaults.standard.bool(forKey: "demo") }
    public static var tab: Int { UserDefaults.standard.integer(forKey: "tab") }

    @MainActor
    public static func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: "darshan.demo") ?? .standard
        defaults.removePersistentDomain(forName: "darshan.demo")
        let store = SettingsStore(defaults: defaults)
        var s = AppSettings()
        let a = UserDefaults.standard
        if let t = a.string(forKey: "theme"), let m = ThemeMode(rawValue: t) { s.theme = m }
        if let c = a.string(forKey: "accent"), let ac = Accent(rawValue: c) { s.accent = ac }
        if let l = a.string(forKey: "lang"), let lg = Language(rawValue: l) { s.language = lg }
        s.rules = [Rule(kind: .extensions, value: "jpg, png", folder: "Photos"),
                   Rule(kind: .nameContains, value: "invoice", folder: "Work/Invoices")]
        s.auto.oldFiles = true; s.auto.duplicates = true
        store.save(s)
        let model = AppModel(store: store, journalURL: nil)
        let folder = makeSampleFolder()
        model.setFolder(folder)
        return model
    }

    /// Runs the action that fills the chosen tab with results, so a screenshot shows real data.
    @MainActor
    public static func prepare(_ model: AppModel, tab: Int) async {
        switch tab {
        case 0:
            await model.sort(.type)
        case 1:
            model.settings.includeSubfolders = true
            await model.scanDuplicates()
        case 2:
            model.settings.oldDays = 90
            await model.previewOld()
        case 3:
            model.renameOptions.extensions = "jpg, png"
            model.renameOptions.baseName = "Photo"
            model.renameOptions.numbering = true
            await model.previewRename()
        case 5:
            model.settings.includeSubfolders = true
            await model.calculateStorage()
        default: break
        }
    }

    static func makeSampleFolder() -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("Downloads-demo", isDirectory: true)
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        func make(_ name: String, kb: Int, seed: UInt8, days: Double = 0) {
            let u = dir.appendingPathComponent(name)
            try? Data(repeating: seed, count: kb * 1024).write(to: u)
            if days > 0 { try? fm.setAttributes([.modificationDate: Date().addingTimeInterval(-days * 86_400)], ofItemAtPath: u.path) }
        }
        make("IMG_2041.jpg", kb: 2400, seed: 1)
        make("IMG_2042.jpg", kb: 1800, seed: 2)
        make("IMG_2042 copy.jpg", kb: 1800, seed: 2, days: -0)
        make("holiday.png", kb: 900, seed: 3)
        make("invoice_october.pdf", kb: 320, seed: 4, days: 40)
        make("Resume.pdf", kb: 210, seed: 5, days: 120)
        make("Resume (1).pdf", kb: 210, seed: 5)
        make("lecture1.mp4", kb: 9000, seed: 6, days: 200)
        make("song.mp3", kb: 3800, seed: 7, days: 150)
        make("notes.txt", kb: 12, seed: 8, days: 300)
        make("project.zip", kb: 5200, seed: 9, days: 15)
        make("main.swift", kb: 6, seed: 10, days: 3)
        try? fm.createDirectory(at: dir.appendingPathComponent("Old stuff"), withIntermediateDirectories: true)
        try? Data(repeating: 4, count: 320 * 1024).write(to: dir.appendingPathComponent("Old stuff/invoice_copy.pdf"))
        try? Data(repeating: 11, count: 700 * 1024).write(to: dir.appendingPathComponent("Old stuff/wallpaper.jpg"))
        return dir
    }
}

/// Root view that prepares demo data once (used when `-demo YES` is passed).
public struct DemoRootView: View {
    @StateObject private var model: AppModel
    @MainActor public init() { _model = StateObject(wrappedValue: DemoMode.makeModel()) }
    public var body: some View {
        RootView(model: model, initialTab: DemoMode.tab)
            .task { await DemoMode.prepare(model, tab: DemoMode.tab) }
    }
}
#endif
