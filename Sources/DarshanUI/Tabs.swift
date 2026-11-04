#if canImport(SwiftUI)
import SwiftUI
import DarshanCore

// MARK: - Sort

struct SortView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th

    var body: some View {
        Page {
            Text(model.t("sort_hint")).font(.system(size: 14)).foregroundStyle(th.secondary)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: model.t("tab_sort"))
                Button { Task { await model.sort(.type) } } label: { Label(model.t("sort_by_type"), systemImage: "square.grid.2x2") .frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(AccentButtonStyle())
                Button { Task { await model.sort(.ext) } } label: { Label(model.t("sort_by_ext"), systemImage: "textformat") .frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(AccentButtonStyle())
                Button { Task { await model.sort(.date) } } label: { Label(model.t("sort_by_date"), systemImage: "calendar") .frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(AccentButtonStyle())
                Button { Task { await model.sort(.rules) } } label: { Label(model.t("apply_rules"), systemImage: "list.bullet.rectangle") .frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(OutlineButtonStyle())
                Button { Task { await model.undo() } } label: { Label(model.t("undo_last"), systemImage: "arrow.uturn.backward") .frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(!model.canUndo)
            }
            .card()
            .disabled(model.busy)

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: model.t("log_title"))
                if model.log.isEmpty {
                    Text(model.t("log_empty")).font(.system(size: 13)).foregroundStyle(th.secondary)
                } else {
                    ForEach(Array(model.log.prefix(12).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 12, design: .monospaced)).foregroundStyle(th.text)
                    }
                }
            }
            .card()
        }
    }
}

// MARK: - Duplicates

struct DuplicatesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 10) {
                CheckRow(title: model.t("include_sub"), isOn: Binding(get: { model.settings.includeSubfolders }, set: { model.settings.includeSubfolders = $0 }))
                Button { Task { await model.scanDuplicates() } } label: { Label(model.t("scan"), systemImage: "magnifyingglass") }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!model.hasFolder || model.busy)
                Text(model.t("dup_note")).font(.system(size: 12)).foregroundStyle(th.secondary)
            }
            .card()

            if model.duplicatesScanned {
                if model.duplicateGroups.isEmpty {
                    Text(model.t("dup_none")).font(.system(size: 15, weight: .semibold)).foregroundStyle(th.text).card()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("dup_groups", [String(model.duplicateGroups.count)])).font(.system(size: 16, weight: .bold)).foregroundStyle(th.text)
                        Text(model.t("dup_wasted", [formatBytes(DuplicateFinder.totalWasted(model.duplicateGroups))])).font(.system(size: 14, weight: .semibold)).foregroundStyle(th.ink)
                    }
                    .card()

                    ForEach(model.duplicateGroups) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(g.original.name + "  ·  " + formatBytes(g.size) + " × " + String(g.files.count))
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(th.ink).lineLimit(1)
                            ForEach(g.files) { f in
                                if f.id == g.original.id {
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(th.ink).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(model.relativePath(f.url)).font(.system(size: 13)).foregroundStyle(th.text).lineLimit(1).truncationMode(.middle)
                                            Text(model.t("dup_keep")).font(.system(size: 11)).foregroundStyle(th.secondary)
                                        }
                                    }
                                } else {
                                    CheckRow(title: model.relativePath(f.url), isOn: Binding(get: { model.duplicateSelection.contains(f.id) }, set: { _ in model.toggleDuplicate(f) }))
                                }
                            }
                        }
                        .card()
                    }

                    Button { Task { await model.moveDuplicates() } } label: { Label(model.t("dup_move") + " (" + formatBytes(model.selectedDuplicateBytes) + ")", systemImage: "arrow.right.doc.on.clipboard") }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(model.duplicateSelection.isEmpty || model.busy)
                }
            }
        }
    }
}

// MARK: - Old files

struct OldFilesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    private let presets = [30, 60, 90, 180, 365]

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: model.t("old_days"))
                Segmented(options: presets.map { ($0, String($0)) }, selection: Binding(get: { model.settings.oldDays }, set: { model.settings.oldDays = $0; model.oldPreview = []; model.oldScanned = false }))
                Stepper(value: Binding(get: { model.settings.oldDays }, set: { model.settings.oldDays = max($0, 1); model.oldPreview = []; model.oldScanned = false }), in: 1...3650) {
                    Text(model.t("days_n", [String(model.settings.oldDays)])).foregroundStyle(th.text)
                }
                CheckRow(title: model.t("include_sub"), isOn: Binding(get: { model.settings.includeSubfolders }, set: { model.settings.includeSubfolders = $0 }))
                Button { Task { await model.previewOld() } } label: { Label(model.t("rename_preview"), systemImage: "eye") }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(!model.hasFolder || model.busy)
            }
            .card()

            if model.oldScanned {
                let bytes = model.oldPreview.reduce(Int64(0)) { $0 + $1.size }
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("old_preview", [String(model.oldPreview.count), formatBytes(bytes), String(model.settings.oldDays)]))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(th.text)
                    ForEach(model.oldPreview.prefix(8)) { f in
                        Text(f.name).font(.system(size: 13)).foregroundStyle(th.secondary).lineLimit(1)
                    }
                    if model.oldPreview.count > 8 { Text("…").foregroundStyle(th.secondary) }
                }
                .card()
                Button { Task { await model.moveOld() } } label: { Label(model.t("old_move"), systemImage: "archivebox") }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(model.oldPreview.isEmpty || model.busy)
            }
        }
    }
}

// MARK: - Rename

struct RenameView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 10) {
                Field(title: model.t("rename_name"), text: $model.renameOptions.nameContains)
                Field(title: model.t("rename_ext"), text: $model.renameOptions.extensions)
                Field(title: model.t("rename_prefix"), text: $model.renameOptions.prefix)
                Field(title: model.t("rename_suffix"), text: $model.renameOptions.suffix)
                Field(title: model.t("rename_find"), text: $model.renameOptions.find)
                Field(title: model.t("rename_replace"), text: $model.renameOptions.replace)
                Field(title: model.t("rename_base"), text: $model.renameOptions.baseName)
                CheckRow(title: model.t("rename_numbering"), isOn: $model.renameOptions.numbering)
                Button { Task { await model.previewRename() } } label: { Label(model.t("rename_preview"), systemImage: "eye") }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(!model.hasFolder || model.busy)
            }
            .card()

            if !model.renamePreview.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.renamePreview.prefix(10)) { r in
                        HStack(spacing: 6) {
                            Text(r.oldName).foregroundStyle(th.secondary).lineLimit(1)
                            Image(systemName: "arrow.right").foregroundStyle(th.ink)
                            Text(r.newName).foregroundStyle(th.text).fontWeight(.semibold).lineLimit(1)
                        }
                        .font(.system(size: 13))
                    }
                    if model.renamePreview.count > 10 { Text("… +" + String(model.renamePreview.count - 10)).foregroundStyle(th.secondary) }
                }
                .card()
                Button { Task { await model.applyRename() } } label: { Label(model.t("rename_apply") + " (" + String(model.renamePreview.count) + ")", systemImage: "pencil") }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(model.busy)
            }
        }
    }
}

// MARK: - Rules

struct RulesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    @State private var editingID: UUID? = nil
    @State private var kind: Rule.Kind = .extensions
    @State private var value = ""
    @State private var folderName = ""

    private func reset() { editingID = nil; kind = .extensions; value = ""; folderName = "" }

    var body: some View {
        Page {
            Text(model.t("rules_hint")).font(.system(size: 14)).foregroundStyle(th.secondary)

            if model.settings.rules.isEmpty {
                Text(model.t("rules_empty")).font(.system(size: 14)).foregroundStyle(th.secondary).card()
            } else {
                ForEach(Array(model.settings.rules.enumerated()), id: \.element.id) { idx, r in
                    HStack(spacing: 10) {
                        Text(String(idx + 1)).font(.system(size: 13, weight: .bold)).foregroundStyle(th.onAccent)
                            .frame(width: 24, height: 24).background(Circle().fill(th.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text((r.kind == .extensions ? model.t("rules_kind_ext") : model.t("rules_kind_name")) + ": " + r.value)
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(th.text).lineLimit(1)
                            Text("→ " + r.folder).font(.system(size: 13)).foregroundStyle(th.ink).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Button { editingID = r.id; kind = r.kind; value = r.value; folderName = r.folder } label: { Image(systemName: "pencil") }
                            .buttonStyle(OutlineButtonStyle())
                        Button { model.deleteRule(r) } label: { Image(systemName: "trash") }
                            .buttonStyle(OutlineButtonStyle())
                    }
                    .card()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: editingID == nil ? model.t("rules_add") : model.t("rules_edit"))
                Segmented(options: [(Rule.Kind.extensions, model.t("rules_kind_ext")), (Rule.Kind.nameContains, model.t("rules_kind_name"))], selection: $kind)
                Field(title: model.t("rules_value"), text: $value)
                Field(title: model.t("rules_folder"), text: $folderName)
                HStack(spacing: 10) {
                    Button {
                        let r = Rule(id: editingID ?? UUID(), kind: kind, value: value, folder: folderName)
                        if r.isValid { model.saveRule(r); reset() }
                    } label: { Label(model.t("rules_save"), systemImage: "checkmark") }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(!Rule(kind: kind, value: value, folder: folderName).isValid)
                    if editingID != nil {
                        Button { reset() } label: { Text(model.t("rules_cancel")) }.buttonStyle(OutlineButtonStyle())
                    }
                }
            }
            .card()
        }
    }
}

// MARK: - Storage

struct StorageView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 10) {
                CheckRow(title: model.t("include_sub"), isOn: Binding(get: { model.settings.includeSubfolders }, set: { model.settings.includeSubfolders = $0 }))
                Button { Task { await model.calculateStorage() } } label: { Label(model.t("storage_scan"), systemImage: "chart.bar") }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!model.hasFolder || model.busy)
            }
            .card()

            if model.usageScanned {
                let total = StorageStats.total(model.usage)
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.t("storage_total", [String(total.count), formatBytes(total.bytes)]))
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(th.text)
                    let maxBytes = max(model.usage.map { $0.bytes }.max() ?? 1, 1)
                    ForEach(model.usage) { u in
                        BarRow(label: L.category(u.category, model.lang),
                               detail: (u.count == 1 ? model.t("file_1") : model.t("files_n", [String(u.count)])) + " · " + formatBytes(u.bytes),
                               fraction: Double(u.bytes) / Double(maxBytes))
                    }
                }
                .card()
            }
        }
    }
}

/// One bar of the storage chart (plain SwiftUI shapes, no Charts framework).
struct BarRow: View {
    @Environment(\.dfm) private var th
    let label: String
    let detail: String
    let fraction: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(th.text)
                Spacer()
                Text(detail).font(.system(size: 12)).foregroundStyle(th.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(th.background)
                    RoundedRectangle(cornerRadius: 6).fill(th.accent)
                        .frame(width: max(8, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    private let dayChoices = [30, 60, 90, 180, 365]
    private let intervalChoices = [1, 5, 15, 30, 60]

    private func auto<T>(_ kp: WritableKeyPath<AutoOptions, T>) -> Binding<T> {
        Binding(get: { model.settings.auto[keyPath: kp] }, set: { model.settings.auto[keyPath: kp] = $0 })
    }

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: model.t("settings_theme"))
                Segmented(options: [(ThemeMode.system, model.t("theme_system")), (ThemeMode.light, model.t("theme_light")), (ThemeMode.dark, model.t("theme_dark"))],
                          selection: Binding(get: { model.settings.theme }, set: { model.settings.theme = $0 }))
                SectionTitle(text: model.t("settings_color"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(Accent.allCases, id: \.self) { a in
                        let selected = model.settings.accent == a
                        Button { model.settings.accent = a } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: a.hex(dark: th.dark))).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(th.secondary.opacity(0.6), lineWidth: 1))
                                Text(L.accent(a, model.lang)).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                    .foregroundStyle(th.text)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 9).fill(th.background))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? th.ink : th.border, lineWidth: selected ? 2.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                SectionTitle(text: model.t("settings_language"))
                Segmented(options: Language.allCases.map { ($0, $0.displayName) },
                          selection: Binding(get: { model.settings.language }, set: { model.settings.language = $0 }))
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: model.t("settings_auto"))
                CheckRow(title: model.t("auto_enable"), subtitle: model.t("auto_note"), isOn: auto(\.enabled))
                CheckRow(title: model.t("auto_rules"), isOn: auto(\.customRules))
                CheckRow(title: model.t("auto_type"), isOn: auto(\.sortByType))
                CheckRow(title: model.t("auto_ext"), isOn: auto(\.sortByExtension))
                CheckRow(title: model.t("auto_date"), isOn: auto(\.sortByDate))
                CheckRow(title: model.t("auto_old"), isOn: auto(\.oldFiles))
                if model.settings.auto.oldFiles {
                    Segmented(options: dayChoices.map { ($0, String($0)) }, selection: auto(\.oldDays))
                }
                CheckRow(title: model.t("auto_dups"), isOn: auto(\.duplicates))
                CheckRow(title: model.t("auto_notify"), isOn: auto(\.notify))
                SectionTitle(text: model.t("auto_interval"))
                Segmented(options: intervalChoices.map { ($0, String($0)) }, selection: auto(\.intervalMinutes))
                Button { Task { await model.runAuto() } } label: { Label(model.t("auto_run_now"), systemImage: "play.fill") }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!model.hasFolder || model.busy)
            }
            .card()
        }
    }
}
#endif
