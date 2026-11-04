#if canImport(SwiftUI)
import SwiftUI

/// The single entry view used by both the macOS and iOS app targets.
public struct DarshanAppView: View {
    nonisolated public init() {}
    @MainActor @ViewBuilder public var body: some View {
        if DemoMode.requested { DemoRootView() } else { RootView() }
    }
}
#endif
