import SwiftUI

private struct EditorSession: Identifiable {
    let id: UUID
    let vm: TierListViewModel
    let title: String
    let createdAt: Date
}

struct HomeView: View {
    @StateObject private var store = TierListStore()
    @StateObject private var pm    = PurchaseManager.shared   // ← 追加
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    @State private var editorSession: EditorSession? = nil
    @State private var showPaywall = false                     // ← 追加

    var body: some View {
        TabView {
            LibraryView(store: store, pm: pm, onOpen: openEditor)   // ← pm を渡す
                .tabItem { Label("ライブラリ", systemImage: "square.grid.2x2") }

            AppSettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .fullScreenCover(item: $editorSession) { session in
            TierEditView(
                vm: session.vm,
                saveId: session.id,
                initialTitle: session.title,
                createdAt: session.createdAt,
                onSave:    { data in store.upsert(data) },
                onDismiss: { editorSession = nil }
            )
            .environment(\.appTheme, appTheme)
            .environment(\.setAppTheme, { appTheme = $0 })
        }
        // ← ペイウォールシート
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(pm: pm)
        }
    }

    private func openEditor(with saveData: TierListSaveData?) {
        // 新規作成かつ上限に達している場合はペイウォールを表示
        if saveData == nil, !pm.canCreate(currentCount: store.savedLists.count) {
            showPaywall = true
            return
        }

        let vm = TierListViewModel()
        if let saveData {
            vm.load(from: saveData)
            editorSession = EditorSession(
                id: saveData.id,
                vm: vm,
                title: saveData.title,
                createdAt: saveData.createdAt
            )
        } else {
            // 新規作成: アプリテーマに合わせて TierTheme を初期化
            vm.tierTheme = appTheme == .dark ? .dark : .classic
            editorSession = EditorSession(
                id: UUID(),
                vm: vm,
                title: "ティア表",
                createdAt: Date()
            )
        }
    }
}

#Preview {
    HomeView()
}
