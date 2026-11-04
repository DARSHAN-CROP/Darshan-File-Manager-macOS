#if canImport(SwiftUI)
import SwiftUI
import DarshanUI

@main
struct DarshanFileManagerApp: App {
    var body: some Scene {
        WindowGroup {
            DarshanAppView()
                .frame(minWidth: 900, idealWidth: 1000, minHeight: 640, idealHeight: 700)
        }
    }
}
#else
@main
struct DarshanFileManagerApp {
    static func main() { print("Darshan File Manager is a macOS app (SwiftUI). Build it on a Mac.") }
}
#endif
