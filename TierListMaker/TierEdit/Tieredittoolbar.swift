import SwiftUI

// MARK: - TierEditToolbar
//
// TierEditView のナビゲーションバーをすべて担う ToolbarContent。
// タイトルの表示・編集・確定ロジックを自己完結させることで、
// TierEditView から @FocusState 以外のタイトル関連状態を排除できる。

struct TierEditToolbar: ToolbarContent {

    // MARK: - Bindings

    @Binding var title: String
    @Binding var isEditing: Bool
    /// TierEditView 側の @FocusState<Bool> を受け取る
    var focused: FocusState<Bool>.Binding
    let maxLength: Int

    // MARK: - Callbacks

    let onBack: () -> Void
    let onExport: () -> Void
    let onSettings: () -> Void

    // MARK: - Body

    var body: some ToolbarContent {

        // ── 左：戻るボタン ──
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.body.bold())
                    Text("ライブラリ").font(.body)
                }
            }
        }

        // ── 中央：タイトル（表示 / 編集を切り替え）──
        ToolbarItem(placement: .principal) {
            titleView
        }

        // ── 右：エクスポート ＋ 設定 ──
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up").font(.body)
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape").font(.body)
            }
        }
    }

    // MARK: - Title View

    @ViewBuilder
    private var titleView: some View {
        if isEditing {
            HStack(spacing: 4) {
                TextField("", text: $title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .focused(focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onSubmit { finishEditing() }
                    .onChange(of: title) { _, newValue in
                        if newValue.count > maxLength {
                            title = String(newValue.prefix(maxLength))
                        }
                    }
                    .frame(maxWidth: 160)

                Button { finishEditing() } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        } else {
            HStack(spacing: 6) {
                Text(title.isEmpty ? "ティア表" : title)
                    .font(.headline)
                    .lineLimit(1)

                Button {
                    isEditing = true
                    focused.wrappedValue = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func finishEditing() {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            title = "ティア表"
        }
        isEditing = false
        focused.wrappedValue = false
    }
}
