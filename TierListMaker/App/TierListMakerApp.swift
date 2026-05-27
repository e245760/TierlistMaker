import SwiftUI

@main
struct TierListMakerApp: App {
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(appTheme.colorScheme)
                .environment(\.appTheme, appTheme)
                .environment(\.setAppTheme, { appTheme = $0 })
                .environmentObject(PurchaseManager.shared) // ← 追加
        }
    }
}

private struct SetAppThemeKey: EnvironmentKey {
    static let defaultValue: (AppTheme) -> Void = { _ in }
}

extension EnvironmentValues {
    var setAppTheme: (AppTheme) -> Void {
        get { self[SetAppThemeKey.self] }
        set { self[SetAppThemeKey.self] = newValue }
    }
}
