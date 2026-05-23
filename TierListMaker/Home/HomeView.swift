import SwiftUI

// エディタに渡すセッション情報をまとめた構造体
private struct EditorSession: Identifiable {
    let id: UUID
    let vm: TierListViewModel
    let title: String
    let createdAt: Date
}

struct HomeView: View {
    @StateObject private var store = TierListStore()
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    @State private var editorSession: EditorSession? = nil

    var body: some View {
        TabView {
            LibraryView(store: store, onOpen: openEditor)
                .tabItem {
                    Label("ライブラリ", systemImage: "square.grid.2x2")
                }

            AppSettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .fullScreenCover(item: $editorSession) { session in
            TierEditView(
                vm: session.vm,
                saveId: session.id,
                initialTitle: session.title,
                createdAt: session.createdAt,
                onSave: { data in store.upsert(data) },
                onDismiss: { editorSession = nil }
            )
            .preferredColorScheme(appTheme.colorScheme)
            .environment(\.appTheme, appTheme)
            .environment(\.setAppTheme, { appTheme = $0 })
        }
    }

    private func openEditor(with saveData: TierListSaveData?) {
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
