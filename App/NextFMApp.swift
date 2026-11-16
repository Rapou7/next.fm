import SwiftUI

@main
struct NextFMApp: App {
    @State private var model = AppModel()
    @ViewBuilder private var appContent: some View {
        #if DEBUG
        DebugHost { RootView() }
        #else
        RootView()
        #endif
    }
    var body: some Scene {
        WindowGroup {
            appContent
                .environment(model)
                .tint(Theme.accent)
                .task { await model.restore() }
        }
    }
}
