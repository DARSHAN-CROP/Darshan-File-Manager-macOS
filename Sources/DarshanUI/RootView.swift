#if canImport(SwiftUI)
import SwiftUI
import DarshanCore
import UniformTypeIdentifiers

enum AppTab: Int, CaseIterable, Identifiable {
    case sort, duplicates, old, rename, rules, storage, settings
    var id: Int { rawValue }
    var key: String {
        switch self {
        case .sort: return "tab_sort"
        case .duplicates: return "tab_duplicates"
        case .old: return "tab_old"
        case .rename: return "tab_rename"
        case .rules: return "tab_rules"
        case .storage: return "tab_storage"
        case .settings: return "tab_settings"
        }
    }
    var icon: String {
        switch self {
        case .sort: return "arrow.up.arrow.down.square"
        case .duplicates: return "doc.on.doc"
        case .old: return "clock.arrow.circlepath"
        case .rename: return "pencil"
        case .rules: return "list.bullet.rectangle"
        case .storage: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

public struct RootView: View {
    @StateObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @State private var tab: AppTab

    @MainActor public init(initialTab: Int = 0) {
        _model = StateObject(wrappedValue: AppModel())
        _tab = State(initialValue: AppTab(rawValue: initialTab) ?? .sort)
    }

    /// For screenshots / tests: start from a prepared model.
    @MainActor public init(model: AppModel, initialTab: Int = 0) {
        _model = StateObject(wrappedValue: model)
        _tab = State(initialValue: AppTab(rawValue: initialTab) ?? .sort)
    }

    private var theme: AppTheme {
        AppTheme(dark: model.settings.theme.isDark(systemIsDark: scheme == .dark), accent: model.settings.accent)
    }

    private var preferred: ColorScheme? {
        switch model.settings.theme { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }

    public var body: some View {
        let th = theme
        ZStack {
            th.background.ignoresSafeArea()
            #if os(macOS)
            HStack(spacing: 0) {
                SidebarView(tab: $tab)
                    .frame(width: 210)
                VStack(spacing: 0) {
                    FolderBar()
                    ContentSwitch(tab: tab)
                }
            }
            #else
            VStack(spacing: 0) {
                HeaderBar(title: model.t(tab.key))
                FolderBar()
                ContentSwitch(tab: tab)
                BottomTabBar(tab: $tab)
            }
            #endif
        }
        .environmentObject(model)
        .environment(\.dfm, th)
        .preferredColorScheme(preferred)
        .tint(th.accent)
        .onChange(of: phase) { p in if p == .active { model.appBecameActive() } }
    }
}

struct ContentSwitch: View {
    let tab: AppTab
    var body: some View {
        switch tab {
        case .sort: SortView()
        case .duplicates: DuplicatesView()
        case .old: OldFilesView()
        case .rename: RenameView()
        case .rules: RulesView()
        case .storage: StorageView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Navigation chrome

struct HeaderBar: View {
    @Environment(\.dfm) private var th
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill").font(.system(size: 20, weight: .bold))
            Text(title).font(.system(size: 20, weight: .bold))
            Spacer()
        }
        .foregroundStyle(th.onAccent)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(th.accent)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    @Binding var tab: AppTab
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill").font(.system(size: 22, weight: .bold))
                    Text("Darshan").font(.system(size: 20, weight: .bold))
                }
                Text("File Manager").font(.system(size: 13, weight: .medium)).opacity(0.9)
            }
            .foregroundStyle(th.onAccent)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(th.accent)

            VStack(spacing: 4) {
                ForEach(AppTab.allCases) { t in
                    Button { tab = t } label: {
                        HStack(spacing: 10) {
                            Image(systemName: t.icon).frame(width: 22)
                            Text(model.t(t.key)).lineLimit(1)
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tab == t ? th.onAccent : th.text)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 9).fill(tab == t ? th.accent : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.top, 8)
            Spacer()
            Text(model.t("footer")).font(.system(size: 11)).foregroundStyle(th.secondary)
                .padding(14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(th.surface)
    }
}

struct BottomTabBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    @Binding var tab: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { t in
                Button { tab = t } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: .semibold))
                        Text(model.t(t.key)).font(.system(size: 9.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(tab == t ? th.ink : th.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(tab == t ? th.ink.opacity(0.14) : Color.clear).padding(.horizontal, 2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 2)
        .background(th.surface.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(th.border).frame(height: 0.5), alignment: .top)
    }
}

struct FolderBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dfm) private var th
    @State private var importing = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder").foregroundStyle(th.ink)
            Text(model.folder?.path ?? model.t("no_folder"))
                .font(.system(size: 13)).foregroundStyle(model.folder == nil ? th.secondary : th.text)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 6)
            Button { importing = true } label: { Text(model.t("choose_folder")).font(.system(size: 13, weight: .semibold)) }
                .buttonStyle(OutlineButtonStyle())
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(th.surface)
        .overlay(Rectangle().fill(th.border).frame(height: 0.5), alignment: .bottom)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let u = urls.first { model.setFolder(u) }
        }
    }
}

/// Common scroll container for every tab.
struct Page<Content: View>: View {
    @Environment(\.dfm) private var th
    @EnvironmentObject private var model: AppModel
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(16)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(th.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(th.surface)
                    .overlay(Rectangle().fill(th.border).frame(height: 0.5), alignment: .top)
            }
        }
    }
}
#endif
