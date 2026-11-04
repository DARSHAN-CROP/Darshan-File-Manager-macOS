#if canImport(SwiftUI)
import SwiftUI
import DarshanCore

extension Color {
    init(hex: String) {
        let n = UInt32(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((n >> 16) & 0xff) / 255, green: Double((n >> 8) & 0xff) / 255, blue: Double(n & 0xff) / 255, opacity: 1)
    }
}

/// Resolved colours for the current theme + accent. Injected through the environment.
public struct AppTheme {
    public let dark: Bool
    public let accentChoice: Accent
    public let accent: Color
    public let onAccent: Color
    public let ink: Color
    public let background: Color
    public let surface: Color
    public let text: Color
    public let secondary: Color
    public let border: Color

    public init(dark: Bool, accent: Accent) {
        let p = Palette.of(dark: dark)
        self.dark = dark
        self.accentChoice = accent
        self.accent = Color(hex: accent.hex(dark: dark))
        self.onAccent = Color(hex: accent.onAccentHex(dark: dark))
        self.ink = Color(hex: accent.inkHex(dark: dark))
        self.background = Color(hex: p.background)
        self.surface = Color(hex: p.surface)
        self.text = Color(hex: p.text)
        self.secondary = Color(hex: p.secondaryText)
        self.border = Color(hex: p.secondaryText).opacity(0.35)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(dark: false, accent: .maroon)
}
extension EnvironmentValues {
    var dfm: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Reusable styles

struct AccentButtonStyle: ButtonStyle {
    @Environment(\.dfm) private var th
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(th.onAccent)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(th.accent))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.dfm) private var th
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(th.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 10).stroke(th.ink, lineWidth: 1.5))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

struct CardModifier: ViewModifier {
    @Environment(\.dfm) private var th
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(th.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(th.border.opacity(0.5), lineWidth: 1))
    }
}
extension View { func card() -> some View { modifier(CardModifier()) } }

/// Checkbox row (custom so it is themed the same everywhere).
struct CheckRow: View {
    @Environment(\.dfm) private var th
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(isOn ? th.accent : Color.clear).frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 6).stroke(isOn ? th.accent : th.secondary, lineWidth: 1.5).frame(width: 24, height: 24)
                    if isOn { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(th.onAccent) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(th.text).font(.system(size: 15))
                    if let s = subtitle { Text(s).foregroundStyle(th.secondary).font(.system(size: 12)) }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Segmented control drawn by us (readable in every theme/accent).
struct Segmented<T: Hashable>: View {
    @Environment(\.dfm) private var th
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<options.count, id: \.self) { i in
                let o = options[i]
                Button { selection = o.0 } label: {
                    Text(o.1)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(selection == o.0 ? th.onAccent : th.text)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selection == o.0 ? th.accent : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11).fill(th.background))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(th.border, lineWidth: 1))
    }
}

struct SectionTitle: View {
    @Environment(\.dfm) private var th
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .bold)).foregroundStyle(th.ink).textCase(.uppercase)
    }
}

/// Text field with a themed box.
struct Field: View {
    @Environment(\.dfm) private var th
    let title: String
    @Binding var text: String
    var body: some View {
        TextField("", text: $text, prompt: Text(title).foregroundColor(th.secondary))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .foregroundStyle(th.text)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8).fill(th.background))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(th.border, lineWidth: 1))
    }
}
#endif
