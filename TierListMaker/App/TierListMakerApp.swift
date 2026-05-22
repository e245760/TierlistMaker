import SwiftUI

@main
struct TierListMakerApp: App {

    // アプリ再起動後も保持される
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some Scene {
        WindowGroup {
            ContentView()
                // システムUIをテーマに追従させる
                .preferredColorScheme(appTheme.colorScheme)
                // 子View全体にテーマを配る（カスタムカラーの参照用）
                .environment(\.appTheme, appTheme)
                // テーマ変更用のバインディングを環境に渡す
                .environment(\.setAppTheme, { appTheme = $0 })
        }
    }
}

// MARK: - テーマ変更アクションの EnvironmentKey
// 設定シートなど深い階層から theme を変更するために使う

private struct SetAppThemeKey: EnvironmentKey {
    static let defaultValue: (AppTheme) -> Void = { _ in }
}

extension EnvironmentValues {
    var setAppTheme: (AppTheme) -> Void {
        get { self[SetAppThemeKey.self] }
        set { self[SetAppThemeKey.self] = newValue }
    }
}
