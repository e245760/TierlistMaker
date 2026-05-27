import SwiftUI

private struct EditorSession: Identifiable {
    let id: UUID
    let vm: TierListViewModel
    let title: String
    let createdAt: Date
}

struct HomeView: View {
    @StateObject private var store = TierListStore()
    @EnvironmentObject private var pm: PurchaseManager // ← @StateObject から変更
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    @State private var editorSession: EditorSession? = nil
    @State private var showPaywall = false

    var body: some View {
        TabView {
            LibraryView(store: store, onOpen: openEditor) // ← pm 引数を削除
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
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
    }

    private func openEditor(with saveData: TierListSaveData?) {
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
        .environmentObject(PurchaseManager.shared)
}
